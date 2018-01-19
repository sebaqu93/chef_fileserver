#
# Cookbook:: create_dfs
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

# Installs windows features specified
[
    'FS-DFS-Namespace',
    'FS-DFS-Replication',
    'FS-Resource-Manager',
    'RSAT-DFS-Mgmt-Con',
    'BranchCache'
].each do |feature|
    dsc_resource 'Install Windows Features' do
        resource :WindowsFeature
        property :Name, feature
        property :Ensure, 'present'
    end
end

# Creates shares for the DFS root
%w[\\DFSRoots \\DFSRoots\\FSRoot].each do |path|
    directory path do
    rights :full_control, 'Everyone'
    end
end

# Change $rootpath if necessary
powershell_script 'create_share' do
    code <<-EOH
    $name = "FSRoot"
    $path = "C:\\DFSRoots\\FSRoot"
    New-SmbShare -Name $name -Path $path -FullAccess Everyone
    EOH
    guard_interpreter :powershell_script
# Skips if directory exists (modify $path accordingly)
    not_if <<-EOH
    $name = hostname
    $path = 'C:\\DFSRoots\\FSRoot'
    [bool](Get-WmiObject -Class Win32_Share -ComputerName $name -Filter "Path='$path'")
    EOH
end

# Creates the DomainV2 namespace 
powershell_script 'create_dfsnroot' do
    code <<-EOH
    $name = hostname
    $target = "\\\\$name\\FSRoot"
    $type = "DomainV2"

    $object = New-DfsnRoot -TargetPath $target -Type $type
    EOH
    guard_interpreter :powershell_script
    not_if <<-EOH
    ($object) {return $true} else {return $false}
    EOH
end

# Creates more shares
path = "\\DFSRoots\\FSRoot\\"
%w{Archive Revoquest Shared User}.each do |dir|
    directory "#{path}#{dir}" do
    rights :full_control, 'Everyone'
    action :create
    recursive true
    end
end
# powershell_script 'create_moreshares' do
#     code <<-EOH
#     $sharenames = "Archive","Revoquest","Shared","User"
#     $domain = "sebaqu.me"
#     $share = "FSRoot"
#     $path = "\\\\$domain\\$share"

#     ForEach ($newshare in $sharenames)
#     {
#         New-Item -path $path\\$newshare -ItemType Directory
#         New-SmbShare -Name $newshare -Path $path\\$newshare -FullAccess Everyone
#     }
#     EOH
#     guard_interpreter :powershell_script
#     # Skip if the folder exists (modify $folder variable accordingly)
#     not_if <<-EOH
#     $folder = "Archive"
#     $domain = "sebaqu.me"
#     $share = "FSRoot"
#     $path = "\\\\$domain\\$share"
#     Test-Path $path\\$folder
#     EOH
# end