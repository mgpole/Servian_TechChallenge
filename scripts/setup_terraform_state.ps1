$ErrorActionPreference = "Stop"

$rgname = $env:TRF_STATE_RG
$store_name = $env:TRF_STATE_ACC
$cntnr_name = $env:TRF_STATE_CNTNR
$location = $env:TRF_LOCATION

Write-Output "rgname = $rgname"
Write-Output "store_name = $store_name"
Write-Output "container_name = $cntnr_name"
Write-Output "location = $location"

#Get storage account
$rg =  Get-AzResourceGroup -name $rgname -Location $location
Write-Output "Found resource group = $rg"
$storage = Get-AzStorageAccount -name $store_name -ResourceGroupName $rgname
Write-Output "Found storage account = $storage"
$acc_ctx = New-AzStorageContext -StorageAccountName $store_name -UseConnectedAccount

#Create container
if ( $null -eq (Get-AzStorageContainer -name $cntnr_name -Context $acc_ctx -ErrorAction SilentlyContinue ) ) {
    Write-Output "Create Container"
    New-AzStorageContainer -Name $cntnr_name -Context $acc_ctx
}