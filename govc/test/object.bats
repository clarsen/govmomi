#!/usr/bin/env bats

load test_helper

@test "object.destroy" {
  vcsim_env

  run govc object.destroy "/enoent"
  assert_failure

  run govc object.destroy
  assert_failure

  vm=$(new_id)
  run govc vm.create "$vm"
  assert_success

  # fails when powered on
  run govc object.destroy "vm/$vm"
  assert_failure

  run govc vm.power -off "$vm"
  assert_success

  run govc object.destroy "vm/$vm"
  assert_success
}

@test "object.rename" {
  vcsim_env

  run govc object.rename "/enoent" "nope"
  assert_failure

  vm=$(new_id)
  run govc vm.create -on=false "$vm"
  assert_success

  run govc object.rename "vm/$vm" "${vm}-renamed"
  assert_success

  run govc object.rename "vm/$vm" "${vm}-renamed"
  assert_failure

  run govc object.destroy "vm/${vm}-renamed"
  assert_success
}

@test "object.mv" {
  vcsim_env

  folder=$(new_id)

  run govc folder.create "vm/$folder"
  assert_success

  for _ in $(seq 1 3) ; do
    vm=$(new_id)
    run govc vm.create -folder "$folder" "$vm"
    assert_success
  done

  result=$(govc ls "vm/$folder" | wc -l)
  [ "$result" -eq "3" ]

  run govc folder.create "vm/${folder}-2"
  assert_success

  run govc object.mv "vm/$folder/*" "vm/${folder}-2"
  assert_success

  result=$(govc ls "vm/${folder}-2" | wc -l)
  [ "$result" -eq "3" ]

  result=$(govc ls "vm/$folder" | wc -l)
  [ "$result" -eq "0" ]
}

@test "object.collect" {
  vcsim_env

  run govc object.collect
  assert_success

  run govc object.collect -json
  assert_success

  run govc object.collect -
  assert_success

  run govc object.collect -json -
  assert_success

  run govc object.collect - content
  assert_success

  run govc object.collect -json - content
  assert_success

  root=$(govc object.collect - content | grep content.rootFolder | awk '{print $3}')

  dc=$(govc object.collect "$root" childEntity | awk '{print $3}' | cut -d, -f1)

  hostFolder=$(govc object.collect "$dc" hostFolder | awk '{print $3}')

  cr=$(govc object.collect "$hostFolder" childEntity | awk '{print $3}' | cut -d, -f1)

  host=$(govc object.collect "$cr" host | awk '{print $3}' | cut -d, -f1)

  run govc object.collect "$host"
  assert_success

  run govc object.collect "$host" hardware
  assert_success

  run govc object.collect "$host" hardware.systemInfo
  assert_success

  uuid=$(govc object.collect "$host" hardware.systemInfo.uuid | awk '{print $3}')
  uuid_s=$(govc object.collect -s "$host" hardware.systemInfo.uuid)
  assert_equal "$uuid" "$uuid_s"

  run govc object.collect "$(govc ls host | head -n1)"
  assert_success

  # test against slice of interface
  setting=$(govc object.collect -s - content.setting)
  result=$(govc object.collect -s "$setting" setting)
  assert_equal "..." "$result"

  # test against an interface field
  run govc object.collect 'network/VM Network' summary
  assert_success

  run govc object.collect -dump -o 'network/VM Network'
  assert_success
  gofmt <<<"$output"

  run govc object.collect -json -o 'network/VM Network'
  assert_success
  jq . <<<"$output"
}

@test "object.collect vcsim" {
  vcsim_env -app 1 -pool 1

  # test that {Cluster}ComputeResource and HostSystem network fields have the expected refs
  for obj in DC0_C0 DC0_C0/DC0_C0_H0 DC0_H0 DC0_H0/DC0_H0; do
    run govc object.collect /DC0/host/$obj network
    assert_success
    echo "obj=$obj"
    assert_matches "DistributedVirtualPortgroup:"
    assert_matches "Network:"
  done

  run govc object.collect -s -type ClusterComputeResource / configStatus
  assert_success green

  run govc object.collect -s -type ClusterComputeResource / effectiveRole # []int32 -> ArrayOfInt
  assert_number

  run govc object.collect -s -type ComputeResource / configStatus
  assert_success "$(printf "green\ngreen")"

  run govc object.collect -s -type ComputeResource / effectiveRole
  assert_number

  run govc object.collect -s -type Datacenter / effectiveRole
  assert_number

  run govc object.collect -s -type Datastore / effectiveRole
  assert_number

  run govc object.collect -s -type DistributedVirtualPortgroup / config.key
  assert_matches dvportgroup-

  run govc object.collect -s -type DistributedVirtualPortgroup / config.name
  assert_matches DC0_DVPG0
  assert_matches DVS0-DVUplinks-

  run govc object.collect -s -type DistributedVirtualPortgroup / effectiveRole
  assert_number

  run govc object.collect -s -type DistributedVirtualSwitch / effectiveRole
  assert_number

  run govc object.collect -s -type DistributedVirtualSwitch / summary.name
  assert_success DVS0

  run govc object.collect -s -type DistributedVirtualSwitch / summary.productInfo.name
  assert_success DVS

  run govc object.collect -s -type DistributedVirtualSwitch / summary.productInfo.vendor
  assert_success "VMware, Inc."

  run govc object.collect -s -type DistributedVirtualSwitch / summary.productInfo.version
  assert_success 6.5.0

  run govc object.collect -s -type DistributedVirtualSwitch / summary.uuid
  assert_matches "-"

  run govc object.collect -s -type Folder / effectiveRole
  assert_number

  run govc object.collect -json -type HostSystem / config.storageDevice.scsiLun
  assert_matches /vmfs/devices

  run govc object.collect -json -type HostSystem / config.storageDevice.scsiTopology
  assert_matches host.ScsiTopology

  run govc object.collect -s -type HostSystem / effectiveRole
  assert_number

  run govc object.collect -s -type Network / effectiveRole
  assert_number

  run govc object.collect -s -type ResourcePool / resourcePool
  # DC0_C0/Resources has 1 child ResourcePool and 1 child VirtualApp
  assert_matches "ResourcePool:"
  assert_matches "VirtualApp:"

  run govc object.collect -s -type VirtualApp / effectiveRole
  assert_number

  run govc object.collect -s -type VirtualApp / name
  assert_success DC0_C0_APP0

  run govc object.collect -s -type VirtualApp / owner
  assert_matches ":"

  run govc object.collect -s -type VirtualApp / parent
  assert_matches ":"

  run govc object.collect -s -type VirtualApp / resourcePool
  assert_success "" # no VirtualApp children

  run govc object.collect -s -type VirtualApp / summary.config.cpuAllocation.limit
  assert_number

  run govc object.collect -s -type VirtualApp / summary.config.cpuAllocation.reservation
  assert_number

  run govc object.collect -s -type VirtualApp / summary.config.memoryAllocation.limit
  assert_number

  run govc object.collect -s -type VirtualApp / summary.config.memoryAllocation.reservation
  assert_number

  run govc object.collect -s -type VirtualApp / vm
  assert_matches "VirtualMachine:"

  run govc object.collect -s -type VirtualMachine / config.tools.toolsVersion
  assert_number

  run govc object.collect -s -type VirtualMachine / effectiveRole
  assert_number

  run govc object.collect -s -type VirtualMachine / summary.guest.toolsStatus
  assert_matches toolsNotInstalled

  run govc object.collect -s -type VirtualMachine / config.npivPortWorldWideName # []int64 -> ArrayOfLong
  assert_success

  run govc object.collect -s -type VirtualMachine / config.vmxConfigChecksum # []uint8 -> ArrayOfByte
  assert_success

  run govc object.collect -s /DC0/vm/DC0_H0_VM0 config.hardware.numCoresPerSocket
  assert_success 1

  run govc object.collect -s -type ClusterComputeResource / summary.effectiveCpu
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.effectiveMemory
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.numCpuCores
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.numCpuThreads
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.numEffectiveHosts
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.numHosts
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.totalCpu
  assert_number

  run govc object.collect -s -type ClusterComputeResource / summary.totalMemory
  assert_number

  run govc object.collect -s -type ComputeResource / summary.effectiveCpu
  assert_number

  run govc object.collect -s -type ComputeResource / summary.effectiveMemory
  assert_number

  run govc object.collect -s -type ComputeResource / summary.numCpuCores
  assert_number

  run govc object.collect -s -type ComputeResource / summary.numCpuThreads
  assert_number

  run govc object.collect -s -type ComputeResource / summary.numEffectiveHosts
  assert_number

  run govc object.collect -s -type ComputeResource / summary.numHosts
  assert_number

  run govc object.collect -s -type ComputeResource / summary.totalCpu
  assert_number

  run govc object.collect -s -type ComputeResource / summary.totalMemory
  assert_number

  run govc object.collect -s -type Network / summary.accessible
  assert_success "$(printf "true\ntrue\ntrue")"

  run govc object.collect -s -type Network / summary.ipPoolName
  assert_success ""

  # check that uuid and instanceUuid are set under both config and summary.config
  for prop in config summary.config ; do
    uuids=$(govc object.collect -s -type m / "$prop.uuid" | sort)
    [ -n "$uuids" ]
    iuuids=$(govc object.collect -s -type m / "$prop.instanceUuid" | sort)
    [ -n "$iuuids" ]

    [ "$uuids" != "$iuuids" ]
  done

  govc vm.create -g ubuntu64Guest my-ubuntu
  assert_success

  govc object.collect -type m / -guest.guestFamily linuxGuest
  assert_success
}

@test "object.collect view" {
  vcsim_env -dc 2 -folder 1

  run govc object.collect -type m
  assert_success

  run govc object.collect -type m / -name '*C0*'
  assert_success

  run govc object.collect -type m / -name
  assert_success

  run govc object.collect -type m / name runtime.powerState
  assert_success

  run govc object.collect -type m -type h /F0 name
  assert_success

  run govc object.collect -type n / name
  assert_success

  run govc object.collect -type enoent / name
  assert_failure

  govc object.collect -wait 5m -s -type m ./vm -name foo &
  pid=$!
  run govc vm.create -on=false foo
  assert_success

  wait $pid # wait for object.collect to exit

  run govc object.collect -s -type m ./vm -name foo
  assert_success

  govc object.collect -wait 5m -s -type d / -name dcx &
  pid=$!
  run govc datacenter.create dcx
  assert_success

  wait $pid # wait for object.collect to exit

  run govc object.collect -s -type d / -name dcx
  assert_success
}

@test "object.collect raw" {
  vcsim_env

  govc object.collect -R - <<EOF | grep serverClock
<?xml version="1.0" encoding="UTF-8"?>
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
 <Body>
  <CreateFilter xmlns="urn:vim25">
   <_this type="PropertyCollector">PropertyCollector</_this>
   <spec>
    <propSet>
     <type>ServiceInstance</type>
     <all>true</all>
    </propSet>
    <objectSet>
     <obj type="ServiceInstance">ServiceInstance</obj>
    </objectSet>
   </spec>
   <partialUpdates>false</partialUpdates>
  </CreateFilter>
 </Body>
</Envelope>
EOF

  govc object.collect -O | grep types.CreateFilter
  govc object.collect -O -json | jq .
}

@test "object.collect index" {
  vcsim_env

  export GOVC_VM=/DC0/vm/DC0_H0_VM0

  # NOTE: '-o' flag uses RetrievePropertiesEx() and mo.ObjectContentToType()
  # By default, WaitForUpdatesEx() is used with raw types.ObjectContent

  run govc object.collect -o $GOVC_VM 'config.hardware[4000]'
  assert_failure

  run govc object.collect -o $GOVC_VM 'config.hardware.device[4000'
  assert_failure

  run govc object.collect -o $GOVC_VM 'config.hardware.device["4000"]'
  assert_failure # Key is int, not string

  run govc object.collect -o -json $GOVC_VM 'config.hardware.device[4000]'
  assert_success

  run jq -r .config.hardware.device[].deviceInfo.label <<<"$output"
  assert_success ethernet-0

  run govc object.collect -o $GOVC_VM 'config.hardware.device[4000].enoent'
  assert_failure # InvalidProperty

  run govc object.collect -o -json $GOVC_VM 'config.hardware.device[4000].deviceInfo.label'
  assert_success

  run govc object.collect -s $GOVC_VM 'config.hardware.device[4000].deviceInfo.label'
  assert_success ethernet-0

  run govc object.collect -o $GOVC_VM 'config.extraConfig[guestinfo.a]'
  assert_failure # string Key requires quotes

  run govc object.collect -o $GOVC_VM 'config["guestinfo.a"]'
  assert_failure

  run govc object.collect -o $GOVC_VM 'config.extraConfig["guestinfo.a"]'
  assert_success # Key does not exist, not an error

  run govc vm.change -e "guestinfo.a=1" -e "guestinfo.b=2"
  assert_success

  run govc object.collect -json $GOVC_VM 'config.extraConfig["guestinfo.b"]'
  assert_success

  run jq -r .[].val.value <<<"$output"
  assert_success 2

  run govc object.collect -o -json $GOVC_VM 'config.extraConfig["guestinfo.b"]'
  assert_success

  run jq -r .config.extraConfig[].value <<<"$output"
  assert_success 2

  run govc object.collect -s $GOVC_VM 'config.extraConfig["guestinfo.b"].value'
  assert_success 2
}

@test "object.find" {
  vcsim_env -ds 2

  unset GOVC_DATACENTER

  run govc find "/enoent"
  assert_failure

  run govc find
  assert_success

  run govc find .
  assert_success

  run govc find /
  assert_success

  govc find -json / | jq .

  run govc find . -type HostSystem
  assert_success

  dc=$(govc find / -type Datacenter | head -1)

  run govc find "$dc" -maxdepth 0
  assert_output "$dc"

  run govc find "$dc/vm" -maxdepth 0
  assert_output "$dc/vm"

  run govc find "$dc" -maxdepth 1 -type Folder
  assert_success
  # /<datacenter>/{vm,network,host,datastore}
  [ ${#lines[@]} -eq 4 ]

  folder=$(govc find -type Folder -name vm)

  vm=$(new_empty_vm)

  run govc find . -name "$vm"
  assert_output "$folder/$vm"

  run govc find -p "$folder/$vm" -type Datacenter
  assert_output "$dc"

  run govc find "$folder" -name "$vm"
  assert_output "$folder/$vm"

  # moref for VM Network
  net=$(govc find -i network -name "$(basename "$GOVC_NETWORK")")

  # $vm.network.contains($net) == true
  run govc find . -type m -name "$vm" -network "$net"
  assert_output "$folder/$vm"

  # remove network reference
  run govc device.remove -vm "$vm" ethernet-*
  assert_success

  # $vm.network.contains($net) == false
  run govc find . -type VirtualMachine -name "$vm" -network "$net"
  assert_output ""

  run govc find "$folder" -type VirtualMachine -name "govc-test-*" -runtime.powerState poweredOn
  assert_output ""

  run govc find "$folder" -type VirtualMachine -name "govc-test-*" -runtime.powerState poweredOff
  assert_output "$folder/$vm"

  run govc vm.power -on "$vm"
  assert_success

  run govc find "$folder" -type VirtualMachine -name "govc-test-*" -runtime.powerState poweredOff
  assert_output ""

  run govc find "$folder" -type VirtualMachine -name "govc-test-*" -runtime.powerState poweredOn
  assert_output "$folder/$vm"

  # output paths should be relative to "." in these cases
  export GOVC_DATACENTER=$dc

  folder="./vm"

  run govc find . -name "$vm"
  assert_output "$folder/$vm"

  run govc find "$folder" -name "$vm"
  assert_output "$folder/$vm"

  # Make sure property filter doesn't match when guest is unset for $vm (issue 1089)
  run govc find "$folder" -type m -guest.ipAddress 0.0.0.0
  assert_output ""

  run govc fields.add -type Datastore ds-mode
  assert_success

  run govc fields.add -type Datastore ds-other
  assert_success

  run govc fields.set ds-mode prod datastore/LocalDS_0
  assert_success

  run govc fields.set ds-other prod datastore/LocalDS_1
  assert_success

  run govc fields.set ds-mode test datastore/LocalDS_1
  assert_success

  run govc fields.set ds-other foo datastore/LocalDS_1
  assert_success

  key=$(govc fields.ls | grep ds-mode | awk '{print $1}')

  run govc find -type s / -customValue "$key:prod" # match specific key:val
  assert_success /DC0/datastore/LocalDS_0

  run govc find -type s / -customValue "*:test" # match any key:val
  assert_success /DC0/datastore/LocalDS_1

  run govc find -type s / -customValue "$key:*" # match specific key w/ any val
  assert_matches /DC0/datastore/LocalDS_0
  assert_matches /DC0/datastore/LocalDS_1

  run govc find -type s / -customValue 0:dev # value doesn't match any entity
  assert_success ""
}

@test "object.find multi root" {
  vcsim_env -dc 2

  run govc find vm
  assert_success # ok as there is 1 "vm" folder relative to $GOVC_DATACENTER

  run govc folder.create vm/{one,two}
  assert_success

  run govc find vm/one
  assert_success

  run govc find vm/on*
  assert_success

  run govc find vm/*o*
  assert_failure # matches 2 objects

  run govc folder.create vm/{one,two}/vm
  assert_success

  # prior to forcing Finder list mode, this would have failed since ManagedObjectList("vm") would have returned
  # all 3 folders named "vm": "vm", "vm/one/vm", "vm/two/vm"
  run govc find vm
  assert_success

  unset GOVC_DATACENTER
  run govc find vm
  assert_failure # without Datacenter specified, there are 0 "vm" folders relative to the root folder

  run govc find -l /
  assert_success

  run govc find -l -i /
  assert_success
  assert_matches :domain-c # ClusterComputeResource moid value
  assert_matches :group- # Folder moid value
  assert_matches :resgroup- # ResourcePool moid value
  assert_matches :dvs- # DistributedVirtualSwitch moid value
}

@test "object.method" {
  vcsim_env_todo

  vm=$(govc find vm -type m | head -1)

  run govc object.method -enable=false -name NoSuchMethod "$vm"
  assert_failure

  run govc object.method -enable=false -name Destroy_Task enoent
  assert_failure

  run govc object.collect -s "$vm" disabledMethod
  ! assert_matches "Destroy_Task" "$output"

  run govc object.method -enable=false -name Destroy_Task "$vm"
  assert_success

  run govc object.collect -s "$vm" disabledMethod
  assert_matches "Destroy_Task" "$output"

  run govc object.method -enable -name Destroy_Task "$vm"
  assert_success

  run govc object.collect -s "$vm" disabledMethod
  ! assert_matches "Destroy_Task" "$output"
}

@test "object.save" {
  vcsim_env

  dir="$BATS_TMPDIR/$(new_id)"
  run govc object.save -v -d "$dir" /DC0/vm
  assert_success

  n=$(ls "$dir"/*.xml | wc -l)
  rm -rf "$dir"
  assert_equal 10 "$n"
}

@test "tree" {
  vcsim_start -dc 2 -folder 1 -pod 1 -nsx 1 -pool 2

  run govc tree
  assert_success

  run govc tree /DC0
  assert_success
}
