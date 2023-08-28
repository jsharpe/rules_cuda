load("@cuda_toolchains//:repositories.bzl", "cuda_repos")

def _init():
    cuda_repos()

toolchain = module_extension(
    implementation = _init,
)
