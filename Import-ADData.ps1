[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$MailDomain,

    [Parameter(Mandatory=$false)]
    [string]$RootOUName = "DEMO",

    [Parameter(Mandatory=$false)]
    [ValidateSet("SamAccountName", "FullName", "InitialAndSurname")]
    [string]$MailFormat = "SamAccountName"
)

Import-Module ActiveDirectory

# --- STEP 0: ENSURE UPN SUFFIX IS REGISTERED ---
Write-Host "--- Checking UPN Suffixes ---" -ForegroundColor Cyan
$forest = Get-ADForest
if ($forest.UPNSuffixes -notcontains $MailDomain) {
    Write-Host "Adding $MailDomain to Forest UPN Suffixes..." -ForegroundColor Yellow
    # Fixed: Using the forest object directly instead of a potentially null DN
    Set-ADForest -Identity $forest -UPNSuffixes @{Add=$MailDomain}
} else {
    Write-Host "UPN Suffix $MailDomain already exists." -ForegroundColor Green
}

# --- CONFIGURATION ---
$domainDN = (Get-ADDomain).DistinguishedName
$groupsOUName = "GROUPS"
$usersOUName = "USERS"

$groupsCsv = ".\groups.csv"
$usersCsv = ".\users.csv"
$defaultPassword = ConvertTo-SecureString "TestPasswort123!" -AsPlainText -Force

# --- STEP 1: ENSURE OU STRUCTURE EXISTS ---
Write-Host "`n--- Checking OU Structure ---" -ForegroundColor Cyan
$rootPath = "OU=$RootOUName,$domainDN"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$RootOUName'")) {
    New-ADOrganizationalUnit -Name $RootOUName -Path $domainDN
}

$groupsPath = "OU=$groupsOUName,$rootPath"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$groupsOUName'" -SearchBase $rootPath)) {
    New-ADOrganizationalUnit -Name $groupsOUName -Path $rootPath
}

$usersPath = "OU=$usersOUName,$rootPath"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$usersOUName'" -SearchBase $rootPath)) {
    New-ADOrganizationalUnit -Name $usersOUName -Path $rootPath
}

# --- STEP 2: PROCESS GROUPS ---
Write-Host "`n--- Processing Groups ---" -ForegroundColor Cyan
if (Test-Path $groupsCsv) {
    $groups = Import-Csv $groupsCsv
    foreach ($group in $groups) {
        if (-not (Get-ADGroup -Filter "Name -eq '$($group.GroupName)'")) {
            New-ADGroup -Name $group.GroupName -GroupScope Global -GroupCategory Security -Path $groupsPath
            Write-Host "Group created: $($group.GroupName)" -ForegroundColor Green
        }
    }
}

# --- STEP 3: PROCESS USERS ---
Write-Host "`n--- Processing Users ---" -ForegroundColor Cyan
if (Test-Path $usersCsv) {
    $users = Import-Csv $usersCsv
    foreach ($user in $users) {
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'")) {
            
            $prefix = switch ($MailFormat) {
                "SamAccountName"     { $user.SamAccountName }
                "FullName"           { "$($user.FirstName).$($user.LastName)" }
                "InitialAndSurname"  { "$($user.FirstName.Substring(0,1)).$($user.LastName)" }
            }

            $userMail = ($prefix + "@" + $MailDomain).ToLower()

            $userParams = @{
                SamAccountName    = $user.SamAccountName
                # Fixed: Added 'Name' parameter to avoid interactive prompt
                Name              = "$($user.FirstName) $($user.LastName)" 
                UserPrincipalName = $userMail 
                GivenName         = $user.FirstName
                Surname           = $user.LastName
                DisplayName       = "$($user.FirstName) $($user.LastName)"
                EmailAddress      = $userMail
                Path              = $usersPath
                AccountPassword   = $defaultPassword
                Enabled           = $true
                ChangePasswordAtLogon = $true
            }
            
            New-ADUser @userParams
            Write-Host "User created: $($user.SamAccountName) ($userMail)" -ForegroundColor Green
        }

        # Membership handling
        if ($user.Groups) {
            $userGroups = $user.Groups -split ","
            foreach ($groupName in $userGroups) {
                Add-ADGroupMember -Identity $groupName.Trim() -Members $user.SamAccountName -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host "`nAD Setup Complete!" -BackgroundColor DarkGreen -ForegroundColor White
