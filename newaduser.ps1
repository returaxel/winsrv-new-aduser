<#
.DESCRIPTION
    - Written to learn more about PowerShell and create test accounts for a lab
.PARAMETER givenName
    - Enter... given name
.PARAMETER surName
    - Enter... surname
.PARAMETER share
    - Switch: Create share & assign drive letter
.EXAMPLE
    - > .\newaduser.ps1 -givenName Anders -surName Andersson
    - Will create a user samaccountname something like: anan222
    - Saves account information to CSV
.NOTES
    - Users are created in the default user ou!!!
    - Don't forget to edit: $server, $domain and $csv
    - Information edited 2021-06-30
#>

## ------ [Initialisations] ------
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$givenName,
    [Parameter(Mandatory=$true)]
    [string]$surName,
    [Parameter(Mandatory=$false)]
    [switch]$share
)

$ErrorActionPreference = "Stop"

# Server
$server = 'localhost'

# Domain suffix, name.surname@ $domain
$domain = 'test.ad'

# Export CSV path and filename
$CSV = '.\new-usr.csv'

## ------ [Classes] ------
class USR {
    hidden  [string]$domain
            [string]$surName
            [string]$givenName
    hidden  [string]$displayName
            [string]$userName
            [string]$email
    hidden  [string]$sAMA
    hidden  [string]$upn
            [string]$pw
    
    USR([string]$domain, [string]$givenName, [string]$surName)
        {
            $this.domain = $domain
            $this.surName = $surName
            $this.givenName = $givenName
            $this.displayName = $this.surName+', '+$this.givenName
            $this.userName = $this.SetUsr()
            $this.email = $this.SetEmail()
            $this.sAMA = $this.userName.Normalize("FormD") -replace '\p{M}'
            $this.upn = ('{0}@{1}' -f $this.userName, $this.domain).Normalize("FormD") -replace '\p{M}'
            $this.pw = $this.SetPwd()
        }
    hidden  [string] SetUsr ()
        {
        [int]   $usrInt = (100..999 | Get-Random) # Add 3 digits to end of username
        [string]$SetUsr = '{0}{1}{2}' -f `
                $this.givenName.Substring(0,2).ToLower(), `
                $this.surName.Substring(0,2).ToLower(), `
                $usrInt
            return $SetUsr.Normalize("FormD") -replace '\p{M}'
        }
    hidden  [string] SetPwd ()
        {
        [int]   $pwint = 1..99 | Get-Random 
        [string]$pwStr = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
        [string]$setPw = '{0}{1}{2}!' -f `
                $pwStr.Substring(0,1).ToUpper(), `
                $pwStr, `
                $pwInt
            return $setPw
        }
    hidden [string] SetEmail ()
        {
            $charCHK = "^\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$"
            $setEmail = ('{0}.{1}@{2}' -f `
                $this.givenName, `
                $this.surName.Replace(' ', ''), `
                $this.domain).Normalize("FormD") -replace '\p{M}'
            if ($setEmail -match $charCHK)
            { 
                return $setEmail
            }
            Throw "Error: Email format is not a-okay, user"+' '+$setEmail
        }     
    }

## ------ [Create user] ------
# Create new object USR 
$usr =[USR]::new($domain, $givenName, $surName)

# Set password 
$pass = ConvertTo-SecureString $usr.pw -AsPlainText -Force

# Hashtable of user parameters
$userParam = @{
    'server'            = $server
    'givenName'         = $usr.givenName
    'surName'           = $usr.surName
    'displayName'       = $usr.displayName
    'sAMAccountName'    = $usr.sAma
    'name'              = $usr.userName
    'emailAddress'      = $usr.email
    'userPrincipalName' = $usr.upn
    'accountPassword'   = $pass
    'homeDrive'         = $letter
    'homeDirectory'     = $homedir
    'enabled'           = '1'
    'passthru'          = $true
}

# New AD-User
New-AdUser @userParam -PassThru

## ------ [Create share] ------
if ($share) {
    # Share settings
    $letter = "Z:"                          # EDIT ME
    $homeDir = 'C:\Users\'+$usr.userName    # EDIT ME
    Write-Output 'Creating share:' $homeDir

    # Create Share
    $homeDir = New-Item -path $homeDir -ItemType Directory -force

    # Directory ACL
    $acl = Get-Acl $homeDir

    # Directory permissions
    $fsRights = [System.Security.AccessControl.FileSystemRights]"Modify"
    $aclType = [System.Security.AccessControl.AccessControlType]::Allow
    $Inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $Propagation = [System.Security.AccessControl.PropagationFlags]"InheritOnly"

    # Directory rules 
    $aclRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($usr.upn, $fsRights, $Inheritance, $Propagation, $aclType)
    $acl.AddAccessRule($aclRule)

    # Apply homeDir access
    Set-Acl -Path $homeDir -AclObject $acl 
}

## ------ [Export CSV] ------
$usr | export-csv $CSV -Encoding UTF8 -Delimiter ";" -NoTypeInformation -Append -Force
