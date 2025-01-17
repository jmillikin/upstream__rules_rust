###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run //sys/complex/3rdparty:crates_vendor
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependnecies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normla dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({_CONDITIONS[condition]: deps.values()})

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normla dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": common_items}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        if condition_triples in crate_aliases:
            crate_aliases[condition_triples].update(deps)
        else:
            crate_aliases.update({_CONDITIONS[condition]: dict(deps.items() + common_items)})

    return selects.with_or(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "": {
        _COMMON_CONDITION: {
            "git2": "@complex_sys__git2-0.14.4//:git2",
        },
    },
}

_NORMAL_ALIASES = {
    "": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "": {
    },
}

_NORMAL_DEV_ALIASES = {
    "": {
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

_PROC_MACRO_ALIASES = {
    "": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "": {
    },
}

_BUILD_DEPENDENCIES = {
    "": {
    },
}

_BUILD_ALIASES = {
    "": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "": {
    },
}

_CONDITIONS = {
    "cfg(unix)": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "complex_sys__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__cc-1.0.73",
        sha256 = "2fff2a6927b3bb87f9595d67196a70493f627687a71d87a0d692242c33f58c11",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cc/1.0.73/download"],
        strip_prefix = "cc-1.0.73",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.cc-1.0.73.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__form_urlencoded-1.0.1",
        sha256 = "5fc25a87fa4fd2094bffb06925852034d90a17f0d1e05197d4956d3555752191",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/form_urlencoded/1.0.1/download"],
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__git2-0.14.4",
        sha256 = "d0155506aab710a86160ddb504a480d2964d7ab5b9e62419be69e0032bc5931c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/git2/0.14.4/download"],
        strip_prefix = "git2-0.14.4",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.git2-0.14.4.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__idna-0.2.3",
        sha256 = "418a0a6fab821475f634efe3ccc45c013f742efe03d853e8d3355d5cb850ecf8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/idna/0.2.3/download"],
        strip_prefix = "idna-0.2.3",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.idna-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__jobserver-0.1.24",
        sha256 = "af25a77299a7f711a01975c35a6a424eb6862092cc2d6c72c4ed6cbc56dfc1fa",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/jobserver/0.1.24/download"],
        strip_prefix = "jobserver-0.1.24",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.jobserver-0.1.24.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libc-0.2.126",
        sha256 = "349d5a591cd28b49e1d1037471617a32ddcda5731b99419008085f72d5a53836",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.126/download"],
        strip_prefix = "libc-0.2.126",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.libc-0.2.126.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libgit2-sys-0.13.4-1.4.2",
        sha256 = "d0fa6563431ede25f5cc7f6d803c6afbc1c5d3ad3d4925d12c882bf2b526f5d1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libgit2-sys/0.13.4+1.4.2/download"],
        strip_prefix = "libgit2-sys-0.13.4+1.4.2",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.libgit2-sys-0.13.4+1.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libz-sys-1.1.8",
        sha256 = "9702761c3935f8cc2f101793272e202c72b99da8f4224a19ddcf1279a6450bbf",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libz-sys/1.1.8/download"],
        strip_prefix = "libz-sys-1.1.8",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.libz-sys-1.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__log-0.4.17",
        sha256 = "abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/log/0.4.17/download"],
        strip_prefix = "log-0.4.17",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.log-0.4.17.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__matches-0.1.9",
        sha256 = "a3e378b66a060d48947b590737b30a1be76706c8dd7b8ba0f2fe3989c68a853f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/matches/0.1.9/download"],
        strip_prefix = "matches-0.1.9",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.matches-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__percent-encoding-2.1.0",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/percent-encoding/2.1.0/download"],
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__pkg-config-0.3.25",
        sha256 = "1df8c4ec4b0627e53bdf214615ad287367e482558cf84b109250b37464dc03ae",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/pkg-config/0.3.25/download"],
        strip_prefix = "pkg-config-0.3.25",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.pkg-config-0.3.25.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__tinyvec-1.6.0",
        sha256 = "87cc5ceb3875bb20c2890005a4e226a4651264a5c75edb2421b52861a0a0cb50",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tinyvec/1.6.0/download"],
        strip_prefix = "tinyvec-1.6.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.tinyvec-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__tinyvec_macros-0.1.0",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download"],
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__unicode-bidi-0.3.8",
        sha256 = "099b7128301d285f79ddd55b9a83d5e6b9e97c92e0ea0daebee7263e932de992",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-bidi/0.3.8/download"],
        strip_prefix = "unicode-bidi-0.3.8",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.unicode-bidi-0.3.8.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__unicode-normalization-0.1.21",
        sha256 = "854cbdc4f7bc6ae19c820d44abdc3277ac3e1b2b93db20a636825d9322fb60e6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-normalization/0.1.21/download"],
        strip_prefix = "unicode-normalization-0.1.21",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.unicode-normalization-0.1.21.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__url-2.2.2",
        sha256 = "a507c383b2d33b5fc35d1861e77e6b383d158b2da5e14fe51b83dfedf6fd578c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/url/2.2.2/download"],
        strip_prefix = "url-2.2.2",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.url-2.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__vcpkg-0.2.15",
        sha256 = "accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/vcpkg/0.2.15/download"],
        strip_prefix = "vcpkg-0.2.15",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.vcpkg-0.2.15.bazel"),
    )
