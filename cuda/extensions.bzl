"""Entry point for extensions used by bzlmod."""

load("//cuda/private:repositories.bzl", "local_cuda")
load("//cuda/private:toolchain.bzl", "register_cuda_toolchains")

cuda_toolkit = tag_class(attrs = {
    "name": attr.string(doc = "Name for the toolchain repository", default = "local_cuda"),
    "toolkit_path": attr.string(doc = "Path to the CUDA SDK"),
})

remote_cuda_toolkit = tag_class(attrs = {
    "toolkit_version": attr.string(doc = "Path to the CUDA SDK"),
})

def _init(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for toolchain in mod.tags.local_toolchain:
            if not mod.is_root:
                fail("Only the root module may override the path for the local cuda toolchain")
            if toolchain.name in registrations.keys():
                if toolchain.toolkit_path == registrations[toolchain.name]:
                    # No problem to register a matching toolchain twice
                    continue
                fail("Multiple conflicting toolchains declared for name {} ({} and {}".format(toolchain.name, toolchain.toolkit_path, registrations[toolchain.name]))
            else:
                registrations[toolchain.name] = toolchain.toolkit_path
        for toolchain in mod.tags.remote_toolchain:
            register_cuda_toolchains(version = toolchain.toolkit_version, register_toolchains = False)
    for name, toolkit_path in registrations.items():
        local_cuda(name = name, toolkit_path = toolkit_path)

toolchain = module_extension(
    implementation = _init,
    tag_classes = {"local_toolchain": cuda_toolkit, "remote_toolchain": remote_cuda_toolkit},
)
