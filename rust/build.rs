fn main() {
    println!("cargo::rerun-if-changed=build.rs");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("android") {
        // NDK r27 的默认页大小为 4 KB；同时约束 LOAD 段与 RELRO 的布局。
        println!("cargo::rustc-link-arg-cdylib=-Wl,-z,max-page-size=16384");
        println!("cargo::rustc-link-arg-cdylib=-Wl,-z,common-page-size=16384");
    }
}
