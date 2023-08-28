"""Entry point for extensions used by bzlmod."""

load("//cuda/private:repositories.bzl", "local_cuda")
load("//cuda/private:toolchain.bzl", "register_cuda_toolchains")

remote_cuda_toolkit = tag_class(attrs = {
    "toolkit_version": attr.string(doc = "Path to the CUDA SDK"),
})

cuda_toolkit = tag_class(attrs = {
    "name": attr.string(doc = "Name for the toolchain repository", default = "local_cuda"),
    "toolkit_path": attr.string(doc = "Path to the CUDA SDK, if empty the environment variable CUDA_PATH will be used to deduce this path."),
})

def _toolchain_repo_impl(rctx):
    rctx.file("BUILD.bazel", executable = False)
    load_statements = "\n".join(["load(\"@{0}//:repositories.bzl\", {0}_cuda_remote_repos=\"cuda_remote_repos\")".format(name) for name in rctx.attr.repo_names])
    cmds = "\n    ".join(["{0}_cuda_remote_repos()".format(name) for name in rctx.attr.repo_names])
    repo_content = """\
{0}

def cuda_repos():\

    {1}
""".format(load_statements, cmds)
    rctx.file("repositories.bzl", content = repo_content, executable = False)

_toolchain_repo = repository_rule(
    implementation = _toolchain_repo_impl,
    attrs = {
        "repo_names": attr.string_list(mandatory = True),
    },
)

def _init(module_ctx):
    registrations = {}
    remote_toolchain_repos = []
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
            remote_toolchain_repos += ["remote_cuda_toolchain"]
            register_cuda_toolchains(version = toolchain.toolkit_version, register_toolchains = False)
    for name, toolkit_path in registrations.items():
        local_cuda(name = name, toolkit_path = toolkit_path)

    _toolchain_repo(name = "cuda_toolchains", repo_names = [name for name in registrations.keys()] + remote_toolchain_repos)

toolchain = module_extension(
    implementation = _init,
    tag_classes = {"local_toolchain": cuda_toolkit, "remote_toolchain": remote_cuda_toolkit},
)
