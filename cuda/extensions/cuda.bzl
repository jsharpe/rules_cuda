"""Entry point for extensions used by bzlmod."""

load("//cuda/private:repositories.bzl", "local_cuda")
load("//cuda/private:toolchain.bzl", "CUDA_VERSIONS_JSON", "register_cuda_toolchains")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

remote_cuda_toolkit = tag_class(attrs = {
    "toolkit_version": attr.string(doc = "Path to the CUDA SDK"),
})

cuda_toolkit = tag_class(attrs = {
    "name": attr.string(doc = "Name for the toolchain repository", default = "local_cuda"),
    "toolkit_path": attr.string(doc = "Path to the CUDA SDK, if empty the environment variable CUDA_PATH will be used to deduce this path."),
})

def _toolchain_repo_impl(rctx):
    toolchain_targets = "\n".join(["""
toolchain(
    name = "nvcc-remote-toolchain-{0}",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
    ],
    toolchain = "@{0}//toolchain:nvcc-remote",
    toolchain_type = "@rules_cuda//cuda:toolchain_type",
    visibility = ["//visibility:public"],
)
""".format(name) for name in rctx.attr.repo_names])

    rctx.file("BUILD.bazel", content = toolchain_targets, executable = False)
    load_statements = "\n".join(["load(\"@{0}//:repositories.bzl\", {0}_cuda_remote_repos=\"cuda_remote_repos\")".format(name) for name in rctx.attr.repo_names])
    cmds = "\n    ".join(["{0}_cuda_remote_repos()".format(name) for name in rctx.attr.repo_names])
    repo_content = """\
{0}

def cuda_repos():

    {1}
""".format(load_statements, cmds)
    rctx.file("repositories.bzl", content = repo_content, executable = False)

_toolchain_repo = repository_rule(
    implementation = _toolchain_repo_impl,
    attrs = {
        "repo_names": attr.string_list(mandatory = True),
    },
)

def _remote_toolchain_impl(module_ctx, *, cuda_version):
    redist = module_ctx.read(Label(CUDA_VERSIONS_JSON[cuda_version]))
    repos = json.decode(redist)
    repos_to_define = dict()
    base_url = "https://developer.download.nvidia.com/compute/cuda/redist/"

    for key in repos:
        if key == "release_date" or key == "release_label" or key == "release_product":
            continue
        for arch in repos[key]:
            if arch == "name" or arch == "license" or arch == "version" or arch == "license_path":
                continue
            http_archive(
                name = "{}-{}".format(key, arch),
                sha256 = repos[key][arch]["sha256"],
                build_file = "@rules_cuda//cuda:templates/BUILD.remote_nvcc",
                urls = [base_url + repos[key][arch]["relative_path"]],
                strip_prefix = repos[key][arch]["relative_path"].split("/")[-1][:-7],
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
            _remote_toolchain_impl(module_ctx, cuda_version = toolchain.toolkit_version)
            register_cuda_toolchains(version = toolchain.toolkit_version, register_toolchains = False)
    for name, toolkit_path in registrations.items():
        local_cuda(name = name, toolkit_path = toolkit_path)

    _toolchain_repo(name = "cuda_toolchains", repo_names = [name for name in registrations.keys()] + remote_toolchain_repos)

toolchain = module_extension(
    implementation = _init,
    tag_classes = {"local_toolchain": cuda_toolkit, "remote_toolchain": remote_cuda_toolkit},
)
