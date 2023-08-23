#This is used to query devices in your Meraki tenant with API key

#Author Alex You

# V2.0 Fix the paging
# V1.0 Working but paging limited to 1000

$apiKey = "YOURAPIKEY"
$headers = @{
    "X-Cisco-Meraki-API-Key" = $apiKey
}

$orgListUrl = "https://api.meraki.com/api/v1/organizations/"
$orgList = Invoke-RestMethod -Uri $orgListUrl -Headers $headers -Method Get
# Initialize the array to hold all devices
$Totaldevices = @()

# Query_day no more than 31 days
$query_days = 31
$query_seconds = $query_days * 86400

# Loop through each organization in the orgList
