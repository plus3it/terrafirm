# AMIs and AMI keys - data structures to represent, no user input considered... yet
locals {
  win_ami_keys        = ["win08", "win12", "win16"]
  lx_ami_keys         = ["centos6", "centos7", "rhel6", "rhel7"]
  win_pkg_ami_keys    = formatlist("%spkg", local.win_ami_keys)
  lx_pkg_ami_keys     = formatlist("%spkg", local.lx_ami_keys)
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
    local.lx_ami_keys[0]     = "spel-minimal-centos-6-hvm-*.x86_64-gp2"
    local.lx_ami_keys[1]     = "spel-minimal-centos-7-hvm-*.x86_64-gp2"
    local.lx_ami_keys[2]     = "spel-minimal-rhel-6-hvm-*.x86_64-gp2"
    local.lx_ami_keys[3]     = "spel-minimal-rhel-7-hvm-*.x86_64-gp2"
    local.win_ami_keys[0]    = "Windows_Server-2008-R2_SP1-English-64Bit-Base*"
    local.win_ami_keys[1]    = "Windows_Server-2012-R2_RTM-English-64Bit-Base*"
    local.win_ami_keys[2]    = "Windows_Server-2016-English-Full-Base*"
    local.lx_builder_ami_key = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server*"
  }

  ami_name_regexes = {
    local.lx_ami_keys[0]     = "spel-minimal-centos-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    local.lx_ami_keys[1]     = "spel-minimal-centos-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    local.lx_ami_keys[2]     = "spel-minimal-rhel-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    local.lx_ami_keys[3]     = "spel-minimal-rhel-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    local.win_ami_keys[0]    = ""
    local.win_ami_keys[1]    = ""
    local.win_ami_keys[2]    = ""
    local.lx_builder_ami_key = ""
  }

  # given any user ami key, which ami to use? (i.e., win08pkg = win08; win08 = win08)
  ami_underlying = merge(
    zipmap(local.win_ami_keys, local.win_ami_keys),
    zipmap(local.win_pkg_ami_keys, local.win_ami_keys),
    zipmap(local.lx_ami_keys, local.lx_ami_keys),
    zipmap(local.lx_pkg_ami_keys, local.lx_ami_keys),
    {
      local.lx_builder_ami_key = local.lx_builder_ami_key
    },
    {
      local.win_builder_ami_key = local.win_all_ami_keys[0]
    },
  )

  # plus3, amazon, and ubuntu canonical
  ami_owners = ["701759196663", "099720109477", "801119661308"]

  ami_virtualization_type = "hvm"
}

# use user input to figure out what needs to be done
locals {
  user_requests = sort(var.tfi_instances)
  win_requests = matchkeys(
    local.win_all_ami_keys,
    local.win_all_ami_keys,
    local.user_requests,
  )
  lx_requests = matchkeys(
    local.lx_all_ami_keys,
    local.lx_all_ami_keys,
    local.user_requests,
  )
  win_request_count     = length(local.win_requests)
  lx_request_count      = length(local.lx_requests)
  win_request_any_count = local.win_request_count == 0 ? 0 : 1
  lx_request_any_count  = local.lx_request_count == 0 ? 0 : 1
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
    local.win_requests
    local.lx_requests
    local.user_requests */

  # Starting from innermost:
  #   reduce to underlying (actual) ami (e.g., win08pkg -> win08),
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

  # only search for AMIs that have been requested and only once (i.e, win08pkg + win08 is only 1 search)
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
    name = "virtualization-type"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibility in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    values = [local.ami_virtualization_type]
  }

  filter {
    name = "name"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibility in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    values = [element(local.ami_filters_to_search, count.index)]
  }

  owners = local.ami_owners
}

