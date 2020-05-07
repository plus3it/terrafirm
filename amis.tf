# AMIs and AMI keys - data structures to represent, no user input considered... yet
locals {
  win_ami_keys        = ["win12", "win16", "win19"]
  lx_ami_keys         = ["centos6", "centos7", "rhel6", "rhel7"]
  win_pkg_ami_keys    = formatlist("%spkg", local.win_ami_keys)
  lx_pkg_ami_keys     = formatlist("%spkg", local.lx_ami_keys)
  win_src_ami_keys    = local.win_ami_keys
  lx_src_ami_keys     = local.lx_ami_keys
  win_all_ami_keys    = sort(concat(local.win_ami_keys, local.win_pkg_ami_keys))
  lx_all_ami_keys     = sort(concat(local.lx_ami_keys, local.lx_pkg_ami_keys))
  win_builder_ami_key = "win-builder"
  lx_builder_ami_key  = "lx-builder"

  all_ami_keys = sort(
    concat(
      local.win_all_ami_keys,
      local.lx_all_ami_keys,
      [local.win_builder_ami_key],
      [local.lx_builder_ami_key],
    ),
  )

  ami_name_filters = {
    (local.lx_ami_keys[0])     = "spel-minimal-centos-6-hvm-*.x86_64-gp2"
    (local.lx_ami_keys[1])     = "spel-minimal-centos-7-hvm-*.x86_64-gp2"
    (local.lx_ami_keys[2])     = "spel-minimal-rhel-6-hvm-*.x86_64-gp2"
    (local.lx_ami_keys[3])     = "spel-minimal-rhel-7-hvm-*.x86_64-gp2"
    (local.win_ami_keys[0])    = "Windows_Server-2012-R2_RTM-English-64Bit-Base*"
    (local.win_ami_keys[1])    = "Windows_Server-2016-English-Full-Base*"
    (local.win_ami_keys[2])    = "Windows_Server-2019-English-Full-Base*"
    (local.lx_builder_ami_key) = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server*"
  }

  ami_name_regexes = {
    (local.lx_ami_keys[0])     = "spel-minimal-centos-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    (local.lx_ami_keys[1])     = "spel-minimal-centos-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    (local.lx_ami_keys[2])     = "spel-minimal-rhel-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    (local.lx_ami_keys[3])     = "spel-minimal-rhel-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    (local.win_ami_keys[0])    = ""
    (local.win_ami_keys[1])    = ""
    (local.win_ami_keys[2])    = ""
    (local.lx_builder_ami_key) = ""
  }

  # given any user ami key, which ami to use? (i.e., win12pkg = win12; win12 = win12)
  ami_underlying = merge(
    zipmap(local.win_src_ami_keys, local.win_src_ami_keys),
    zipmap(local.win_pkg_ami_keys, local.win_ami_keys),
    zipmap(local.lx_src_ami_keys, local.lx_src_ami_keys),
    zipmap(local.lx_pkg_ami_keys, local.lx_ami_keys),
    {
      (local.lx_builder_ami_key) = local.lx_builder_ami_key
    },
    {
      (local.win_builder_ami_key) = local.win_all_ami_keys[0]
    },
  )

  # plus3, amazon, and ubuntu canonical
  ami_owners = ["701759196663", "099720109477", "801119661308"]

  ami_virtualization_type = "hvm"
}

# use user input to figure out what needs to be done
locals {
  user_requests = sort(var.tfi_instances)

  win_src_requests = matchkeys(
    local.win_src_ami_keys,
    local.win_src_ami_keys,
    local.user_requests,
  )
  lx_src_requests = matchkeys(
    local.lx_src_ami_keys,
    local.lx_src_ami_keys,
    local.user_requests,
  )
  win_pkg_requests = matchkeys(
    local.win_pkg_ami_keys,
    local.win_pkg_ami_keys,
    local.user_requests,
  )
  lx_pkg_requests = matchkeys(
    local.lx_pkg_ami_keys,
    local.lx_pkg_ami_keys,
    local.user_requests,
  )

  win_src_count = length(local.win_src_requests)
  lx_src_count  = length(local.lx_src_requests)
  win_pkg_count = length(local.win_pkg_requests)
  lx_pkg_count  = length(local.lx_pkg_requests)
  win_any       = (local.win_src_count + local.win_pkg_count) == 0 ? 0 : 1
  lx_any        = (local.lx_src_count + local.lx_pkg_count) == 0 ? 0 : 1

  win_need_builder = length(local.win_pkg_requests) > 0 ? 1 : 0
  lx_need_builder  = length(local.lx_pkg_requests) > 0 ? 1 : 0
  win_builder_list = [
    local.win_need_builder == 1 ? local.ami_underlying[local.win_builder_ami_key] : "",
  ]
  lx_builder_list = [
    local.lx_need_builder == 1 ? local.ami_underlying[local.lx_builder_ami_key] : "",
  ]

  /* Ordering of several lists are very important so that requests match up to
  the instance delivered.
    local.amis_to_search
    local.ami_filters_to_search
    local.win_src_requests
    local.lx_src_requests
    local.win_pkg_requests
    local.lx_pkg_requests
    local.user_requests */

  # Starting from innermost:
  #   reduce to underlying (actual) ami (e.g., win12pkg -> win12),
  #   concat = combine with builder lists in case 1 or both builders are needed,
  #   compact = get rid of empty builder lists (empty string lists) if they aren't needed,
  #   reduce to distinct values,
  #   matchkeys = order list the same as other lists, based on ami_name_filters order
  amis_to_search = matchkeys(
    keys(local.ami_name_filters),
    keys(local.ami_name_filters),
    distinct(
      compact(
        concat(
          matchkeys(
            values(local.ami_underlying),
            keys(local.ami_underlying),
            local.user_requests,
          ),
          local.win_builder_list,
          local.lx_builder_list,
        ),
      ),
    ),
  )

  # only search for AMIs that have been requested and only once (i.e, win12pkg + win12 is only 1 search)
  ami_filters_to_search = matchkeys(
    values(local.ami_name_filters),
    keys(local.ami_name_filters),
    local.amis_to_search,
  )

  # get regex for appropriate AMIs
  ami_regexes_to_search = matchkeys(
    values(local.ami_name_regexes),
    keys(local.ami_name_regexes),
    local.amis_to_search,
  )

  # one stop shop / data structure for getting ami id with ami key
  ami_ids = zipmap(local.amis_to_search, data.aws_ami.find_amis.*.id)
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "find_amis" {
  count       = length(local.ami_filters_to_search)
  most_recent = true

  name_regex = element(local.ami_regexes_to_search, count.index)

  filter {
    name   = "virtualization-type"
    values = [local.ami_virtualization_type]
  }

  filter {
    name   = "name"
    values = [element(local.ami_filters_to_search, count.index)]
  }

  owners = local.ami_owners
}
