param (
    [string]$prenom,
    [string]$nom,
    [string]$numeroEmp,
    [string]$departementDirection,
    [string]$fonction,
    [string]$numeroIncident,
    [string]$mailDemandeur,
    [string]$mailPersonelUtilisateur
)

# Prérequis: S'assurer que le module Active Directory est installé et que l'utilisateur exécutant ce script a les droits nécessaires.

# Fonction pour envoyer des notifications à Octopus
function Send-OctopusNotification {
    param (
        [string]$IncidentID,
        [string]$Message
    )
    # Cette fonction devrait envoyer la notification via l'API Octopus (à adapter selon les besoins de votre infrastructure Octopus)
    Write-Host "Notification envoyée pour l'incident $IncidentID : $Message"
}

# Vérifier si l'utilisateur existe déjà dans Active Directory en utilisant le numéro d'employé
$existingUser = Get-ADUser -Filter {EmployeeID -eq $numeroEmp} -Properties *
if ($existingUser) {
    # Si l'utilisateur existe déjà, envoyer une notification dans Octopus
    Send-OctopusNotification -IncidentID $numeroIncident -Message "L'utilisateur avec le numéro d'employé $numeroEmp existe déjà dans Active Directory."
    Write-Host "L'utilisateur existe déjà. Notification envoyée dans Octopus."
    exit
}

# Si l'utilisateur n'existe pas, procéder à la création de l'utilisateur

# Générer un mot de passe temporaire
$passwordForce = "TempPassword123!"

# Créer un utilisateur dans Active Directory
$fullName = "$prenom $nom"
$email = $mailPersonelUtilisateur
$SamAccountName = $numeroEmp
$userPrincipalName = "$SamAccountName@cegeplevis.ca"

try {
    # Création de l'utilisateur
    New-ADUser -SamAccountName $SamAccountName `
               -UserPrincipalName $userPrincipalName `
               -Name $fullName `
               -GivenName $prenom `
               -Surname $nom `
               -DisplayName $fullName `
               -EmailAddress $email `
               -AccountPassword (ConvertTo-SecureString -AsPlainText $passwordForce -Force) `
               -Enabled $true `
               -PassThru

    # Si la création de l'utilisateur réussit, envoyer une notification de succès
    Send-OctopusNotification -IncidentID $numeroIncident -Message "L'utilisateur avec le numéro d'employé $numeroEmp a été créé avec succès dans Active Directory."
    Write-Host "L'utilisateur a été créé avec succès."

} catch {
    # En cas d'erreur, envoyer une notification d'erreur
    Send-OctopusNotification -IncidentID $numeroIncident -Message "Erreur lors de la création de l'utilisateur $numeroEmp dans Active Directory. $($_.Exception.Message)"
    Write-Host "Erreur lors de la création de l'utilisateur : $($_.Exception.Message)"
    exit
}

# Ajouter l'utilisateur à un ou plusieurs groupes Active Directory
# Liste des groupes à ajouter, à personnaliser selon les besoins
$groups = @("NomDuGroupe") # Remplacer par le(s) groupe(s) adéquat(s)

foreach ($group in $groups) {
    try {
        Add-ADGroupMember -Identity $group -Members $SamAccountName
        Write-Host "L'utilisateur a été ajouté au groupe $group."
    } catch {
        Write-Host "Erreur lors de l'ajout de l'utilisateur au groupe $group : $($_.Exception.Message)"
    }
}

# Marquer la demande comme traitée dans Octopus
Send-OctopusNotification -IncidentID $numeroIncident -Message "La demande de création de compte pour l'utilisateur $numeroEmp a été traitée."
Write-Host "La demande a été marquée comme traitée dans Octopus."
