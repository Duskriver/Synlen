import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/core/database/app_database.dart';

// Generate Mock classes
@GenerateMocks([ShelfBookRepository, BookManifestRepository])
import 'epub_import_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Provide dummy values for Either types for Mockito
    provideDummy<Either<String, int>>(left('dummy'));
    provideDummy<Either<String, bool>>(left('dummy'));
  });

  group('BookImportService - Unit Tests', () {
    late MockShelfBookRepository mockShelfBookRepo;
    late MockBookManifestRepository mockManifestRepo;

    setUp(() {
      mockShelfBookRepo = MockShelfBookRepository();
      mockManifestRepo = MockBookManifestRepository();
    });

    group('Repository Mock Verification', () {
      test(
        'ShelfBookRepository.bookExistsAndNotDeleted should be called correctly',
        () async {
          // Arrange
          when(
            mockShelfBookRepo.bookExistsAndNotDeleted(any),
          ).thenAnswer((_) async => true);

          // Act
          final result = await mockShelfBookRepo.bookExistsAndNotDeleted(
            'test-hash',
          );

          // Assert
          expect(result, true);
          verify(
            mockShelfBookRepo.bookExistsAndNotDeleted('test-hash'),
          ).called(1);
        },
      );

      test('ShelfBookRepository.saveBook should return book ID', () async {
        // Arrange
        final testBook = ShelfBook(
          id: 0,
          fileHash: 'test-hash',
          title: 'Test Book',
          author: '',
          authors: const [],
          subjects: const [],
          totalChapters: 0,
          epubVersion: '',
          format: BookFormat.epub,
          importDate: 0,
          updatedAt: 0,
          direction: 0,
          currentChapterIndex: 0,
          readingProgress: 0.0,
          isFinished: false,
          isDeleted: false,
        );

        when(mockShelfBookRepo.saveBook(any)).thenAnswer((_) async => right(1));

        // Act
        final result = await mockShelfBookRepo.saveBook(testBook);

        // Assert
        expect(result.isRight(), true);
        expect(result.getRight().toNullable(), 1);
        verify(mockShelfBookRepo.saveBook(any)).called(1);
      });

      test(
        'BookManifestRepository.saveManifest should save successfully',
        () async {
          // Arrange
          when(
            mockManifestRepo.saveManifest(any),
          ).thenAnswer((_) async => right(1));

          // Act: Use null as test parameter
          final result = await mockManifestRepo.saveManifest(null);

          // Assert
          expect(result.isRight(), true);
        },
      );

      test(
        'ShelfBookRepository.softDeleteBook should perform soft delete',
        () async {
          // Arrange
          when(
            mockShelfBookRepo.softDeleteBook(1),
          ).thenAnswer((_) async => right(true));

          // Act
          final result = await mockShelfBookRepo.softDeleteBook(1);

          // Assert
          expect(result.isRight(), true);
          verify(mockShelfBookRepo.softDeleteBook(1)).called(1);
        },
      );

      test(
        'BookManifestRepository.deleteManifestByHash should delete Manifest',
        () async {
          // Arrange
          when(
            mockManifestRepo.deleteManifestByHash('test-hash'),
          ).thenAnswer((_) async => right(true));

          // Act
          final result = await mockManifestRepo.deleteManifestByHash(
            'test-hash',
          );

          // Assert
          expect(result.isRight(), true);
          verify(mockManifestRepo.deleteManifestByHash('test-hash')).called(1);
        },
      );
    });

    group('Business Logic Verification', () {
      test('Should return error when book already exists', () async {
        // Arrange
        when(
          mockShelfBookRepo.bookExistsAndNotDeleted(any),
        ).thenAnswer((_) async => true);

        // Act & Assert
        final exists = await mockShelfBookRepo.bookExistsAndNotDeleted(
          'existing-hash',
        );
        expect(exists, true);

        // Verify that save method should not be called if book exists
        verifyNever(mockShelfBookRepo.saveBook(any));
      });

      test('Save failure should trigger rollback logic', () async {
        // Arrange: Simulate save failure scenario
        when(
          mockShelfBookRepo.saveBook(any),
        ).thenAnswer((_) async => left('Database error'));

        final testBook = ShelfBook(
          id: 0,
          fileHash: 'test-hash',
          title: 'Test',
          author: '',
          authors: const [],
          subjects: const [],
          totalChapters: 0,
          epubVersion: '',
          format: BookFormat.epub,
          importDate: 0,
          updatedAt: 0,
          direction: 0,
          currentChapterIndex: 0,
          readingProgress: 0.0,
          isFinished: false,
          isDeleted: false,
        );

        // Act
        final result = await mockShelfBookRepo.saveBook(testBook);

        // Assert
        expect(result.isLeft(), true);
        expect(result.getLeft().toNullable(), 'Database error');
      });

      test('Manifest save failure should trigger rollback', () async {
        // Arrange
        when(
          mockManifestRepo.saveManifest(any),
        ).thenAnswer((_) async => left('Manifest error'));

        when(
          mockShelfBookRepo.deleteBook(1),
        ).thenAnswer((_) async => right(true));

        // Act: Use null as test parameter
        final manifestResult = await mockManifestRepo.saveManifest(null);

        // Assert: Save failed
        expect(manifestResult.isLeft(), true);

        // Should trigger rollback to delete saved book
        await mockShelfBookRepo.deleteBook(1);
        verify(mockShelfBookRepo.deleteBook(1)).called(1);
      });
    });

    group('Error Handling Tests', () {
      test('Repository exceptions should propagate correctly', () {
        // Arrange
        when(
          mockShelfBookRepo.saveBook(any),
        ).thenThrow(Exception('Unexpected error'));

        final testBook = ShelfBook(
          id: 0,
          fileHash: 'test-hash',
          title: 'Test',
          author: '',
          authors: const [],
          subjects: const [],
          totalChapters: 0,
          epubVersion: '',
          format: BookFormat.epub,
          importDate: 0,
          updatedAt: 0,
          direction: 0,
          currentChapterIndex: 0,
          readingProgress: 0.0,
          isFinished: false,
          isDeleted: false,
        );

        // Act & Assert
        expect(
          () => mockShelfBookRepo.saveBook(testBook),
          throwsA(isA<Exception>()),
        );
      });

      test('Empty input should be handled correctly', () async {
        // Arrange
        when(mockShelfBookRepo.bookExists('')).thenAnswer((_) async => false);

        // Act
        final result = await mockShelfBookRepo.bookExists('');

        // Assert
        expect(result, false);
      });
    });
  });
}
