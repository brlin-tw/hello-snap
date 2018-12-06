#!/usr/bin/env bash
# Program to set snap's version, used by the `version-script` keyword
# 林博仁(Buo-ren, Lin) <Buo.Ren.Lin@gmail.com> © 2018

set \
	-o errexit \
	-o errtrace \
	-o nounset \
	-o pipefail

init(){
	local \
		all_upstream_release_tags \
		last_upstream_release_version \
		last_snapped_release_version \
		upstream_version \
		packaging_revision

	#DISABLED: Git submodule pulls down too much history, re-implement the pull step until the submodule fetch depth is customizable
	#snapcraftctl pull

	git clone \
		--depth=50 \
		git://git.savannah.gnu.org/hello.git \
		.

	if \
		! \
		git describe \
			--match 'v*' \
			--tags \
			>/dev/null; then
		printf -- \
			'Assertion error: No release tags found, cannot determine which revision to build the snap, increase the clone depth!\n' \
			1>&2
		exit 1
	fi

	all_upstream_release_tags="$(
		git tag \
			--list \
			'v*'
	)"

	# We stripped out the prefix 'v' here
	last_upstream_release_version="$(
		sed 's/^v//' <<< "${all_upstream_release_tags}" \
			| sort --version-sort \
			| tail --lines=1
	)"

	last_snapped_release_version="$(
		snap info "${SNAPCRAFT_PROJECT_NAME}" \
			| awk '$1 == "stable:" { print $2 }' \
			| cut --delimiter=+ --fields=1
	)"

	# If the latest tag from the upstream project has not been released to the stable channel, build that tag instead of the development snapshot and publish it in the edge channel.
	if [ "${last_upstream_release_version}" != "${last_snapped_release_version}" ]; then
		git checkout v"${last_upstream_release_version}"
	fi

	unset \
		all_upstream_release_tags \
		last_upstream_release_version \
		last_snapped_release_version

	# gnulib submodule has LOTS of history, use the --recommend-shallow feature of git-submodule to avoid pulling all of the history:
	# DISABLED: Unfortunately the git server git.savannah.gnu.org doesn't allow it: (error: Server does not allow request for unadvertised object)
	#git config \
		#--file .gitmodules \
		#submodule.gnulib.shallow \
		#true

	git submodule init

	# Currently gnulib has about 1980 revisions to the v2.10 submodule pinned commit:
	# http://git.savannah.gnu.org/cgit/gnulib.git/log/?qt=range&q=master...e8f86ce9^1&ofs=1000
	# use a reasonably large fetch depth
	git submodule update \
		--depth=2000

	upstream_version="$(
		git \
			describe \
			--always \
			--dirty=-d \
			--tags \
		| sed s/^v//
	)"

	packaging_revision="$(
		git \
			describe \
			--abbrev=4 \
			--always \
			--match nothing \
			--dirty=-d
	)"

	snapcraftctl \
		set-version \
		"${upstream_version}+pkg-${packaging_revision}"

	exit 0
}

init "${@}"
