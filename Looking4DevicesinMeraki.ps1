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
foreach ($org in $orgList) {
    $orgId = $org.id

    $networklistUrl = "https://api.meraki.com/api/v1/organizations/$orgId/networks"
    $networklist = Invoke-RestMethod -Uri $networklistUrl -Headers $headers -Method Get

    # Loop through each network in the networklist
    foreach ($network in $networklist) {
        $networkId = $network.id

        # Initialize variables for paging
        $perPage = 1000
        $startingAfter = $null

        # Loop for paging
        do {
            $devicelistUrl = "https://api.meraki.com/api/v1/networks/$networkId/clients?perPage=$perPage&timespan=$query_seconds"
            if ($startingAfter) {
                $devicelistUrl += "&startingAfter=$startingAfter"
            }

            $devicelist = Invoke-RestMethod -Uri $devicelistUrl -Headers $headers -Method Get
            Write-Host "For $($network.name) $($networkId) had $($devicelist.count) devices in last $($query_days) days" -ForegroundColor Yellow -BackgroundColor Black
            if ($devicelist.count -gt $perPage) {
                Write-Host "For $($network.name) $($networkId) exceed $perPage devices in last $($query_days) days" -ForegroundColor Red -BackgroundColor Black
            }

            # Add location information to each device in the list
            $devicelist | ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name "Location" -Value $network.name
            }

            # Append the devices to the Totaldevices array
            $Totaldevices += $devicelist

            # Set the startingAfter parameter for the next page
            if ($devicelist[-1]) {
                $startingAfter = $devicelist[-1].id
            } else {
                $startingAfter = $null
            }

        } while ($startingAfter)
    }
}

$Totaldevices

$report = $DellDevices
Write-Output "Report Completed"
$tableColumns=""
$columns = $report[0].PSObject.Properties.Name
$tableColumns = "<tr>"
$columns | ForEach-Object {
    $tableColumns += "<th>$_</th>"
}
$tableColumns += "</tr>"

#Common Table Contents
Write-output "[INFO] `t *** PROCESS REPORT CONTENTS***"
$tableContent=""
$tableContent = $report | ForEach-Object {
    $currentItem = $_
    $rowTemplate = $columns | ForEach-Object {
        $propertyName = $_
        "<td>$($currentItem.$propertyName)</td>"
    }
    "<tr>$($rowTemplate -join '')</tr>"
} | Out-String

Write-output "[INFO] `t *** GENERATE REPORT HTML BODY***"
# Define the HTML body with the dynamic table
$htmlBody = @"
<html>
<head>
<style>
    .table {
        font-family: Arial, Helvetica, sans-serif;
        border-collapse: collapse;
        width: 100%;
    }
    .table th, .table td {
        border: 1px solid #ddd;
        padding: 8px;
    }
    .table tr:nth-child(even) {
        background-color: #f2f2f2;
    }
    .table tr:hover {
        background-color: #ddd;
    }
    .table th {
        padding-top: 12px;
        padding-bottom: 12px;
        text-align: left;
        background-color: #04AA6D;
        color: white;
    }
</style>
</head>
<body>
<h2>[$Date] Last 31 days All Dell devices in Meraki with mac and locations </h2>
<table class="table">
    $tableColumns
    $tableContent
</table>
</body>
<P><b>Script executed in Alex Local Laptop</b></p>
<P><b>Script Name: Test</b></p>
<P><b>Author: Alex You</b></p>
<P><b>Date 9/08/2023</b></p>

</html>
"@
Write-output "[INFO] `t *** COMPLETE REPORT HTML BODY***"

Write-output $htmlBody
$csvData = ($Totaldevices | ConvertTo-Csv -NoTypeInformation) -join "`r`n"

# Define the email parameters
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$senderEmail = "uniting.helpdesk.automation1@vt.uniting.org"
$senderPassword = "!of66fp[It1g4{]F.ALW^)ZmY)Ob%>"
#$recipientEmail = "alex.you@vt.uniting.org"
$recipientEmail = "ICT-Infra-EmailAlerts@vt.uniting.org , UnitingICT@vt.uniting.org , ICT-HelpDesk-EmailAlerts@vt.uniting.org"
#$recipientEmail = "ict-infrateam@vt.uniting.org"
$subject = "[$Date] All Dell devices in Meraki with mac and locations"
        
# Create a new SMTP client
$smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
$smtpClient.EnableSsl = $true
$smtpClient.Credentials = New-Object System.Net.NetworkCredential($senderEmail, $senderPassword)
    
# Create a new mail message
$mailMessage = New-Object System.Net.Mail.MailMessage
$mailMessage.From = New-Object System.Net.Mail.MailAddress($senderEmail)
$mailMessage.To.Add($recipientEmail)
$mailMessage.Subject = $subject
$mailMessage.Body = $htmlBody
$mailMessage.IsBodyHtml = $true

# Attach the CSV file to the email
$csvMemoryStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($csvData))
$attachment = New-Object System.Net.Mail.Attachment($csvMemoryStream, "AllClients.csv", "text/csv")
$mailMessage.Attachments.Add($attachment)


# Send the email
$smtpClient.Send($mailMessage)
    
# Clean up
$mailMessage.Attachments.Dispose()
$mailMessage.Dispose()
$smtpClient.Dispose()