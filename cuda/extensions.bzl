"""Entry point for extensions used by bzlmod."""

load("//cuda/private:repositories.bzl", "local_cuda")

def _init(module_ctx):
    local_cuda(name = "local_cuda")

ext = module_extension(implementation = _init)
