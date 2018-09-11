
$AMIKey = "${tfi_ami_key}"
$CountIndex = "${tfi_count_index}"
$IndexStr = "win-$CountIndex-"
If($CountIndex -eq "builder")
{
  $IndexStr = ""
}
