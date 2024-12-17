# Paramètres initiaux
param (
    [string]$FtpServer = "adresse_serveur_FTP",               # Adresse du serveur FTP
    [string]$FtpUsername = "nom_utilisateur_FTP",                     # Nom d'utilisateur FTP
    [string]$FtpPassword = "mot_de_passe_FTP",                      # Mot de passe FTP
    [string]$RemoteFilePath = "chemin_fichier_distant",  # Chemin du fichier distant
    [string]$LocalFilePath = "chemin_accès_fichier_local",   # Chemin du fichier local
    [string]$AdminEmail = "adresse_mail_administrateur",            # Email de l'administrateur
    [string]$SmtpServer = "adresse_serveur_SMTP",             # Serveur SMTP pour les emails
    [int]$SmtpPort = 587,                                 # Port SMTP (souvent 587 ou 465)
    [string]$SmtpUser = "adresse_mail_utilisateur_SMTP",               # Utilisateur SMTP
    [string]$SmtpPassword = "votre_mot_de_passe_mail_SMTP"           # Mot de passe SMTP
)

# Configuration des logs
$LogPath = "C:\Logs\FtpDownloadLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
New-Item -Path $LogPath -ItemType File -Force | Out-Null
Write-Host "[$(Get-Date)] Script démarré. Les logs sont enregistrés dans $LogPath" -ForegroundColor Yellow

function Send-Notification {
    param (
        [string]$To,
        [string]$Subject,
        [string]$Body
    )
    try {
        # Créer un objet Credential
        Write-Host "[$(Get-Date)] Tentative d'envoi de l'email à $To..." -ForegroundColor Yellow
        $Credential = [PSCredential]::new($SmtpUser, (ConvertTo-SecureString $SmtpPassword -AsPlainText -Force))

        # Envoi de l'email
        Send-MailMessage -SmtpServer $SmtpServer -Port $SmtpPort -From $SmtpUser -To $To -Subject $Subject -Body $Body -UseSsl -Credential $Credential
        Add-Content -Path $LogPath -Value "$(Get-Date): Email envoyé avec succès à $To"
        Write-Host "[$(Get-Date)] Email envoyé avec succès à $To" -ForegroundColor Green
    } catch {
        Add-Content -Path $LogPath -Value "$(Get-Date): Échec de l'envoi de l'email: $_"
        Write-Host "[$(Get-Date)] Échec de l'envoi de l'email : $_" -ForegroundColor Red
    }
}


# Fonction de téléchargement FTP
function Download-FromFtp {
    param (
        [string]$RemoteFilePath,
        [string]$LocalFilePath,
        [string]$Server,
        [string]$Username,
        [string]$Password
    )
    try {
        # Construire l'URI FTP
        $Uri = "ftp://$($Username):$($Password)@$($Server)$($RemoteFilePath)"
        Write-Host "[$(Get-Date)] Tentative de téléchargement du fichier depuis $Uri..." -ForegroundColor Yellow
        Add-Content -Path $LogPath -Value "$(Get-Date): Tentative de téléchargement du fichier à partir de $Uri"

        # Initialiser la requête FTP
        $FtpWebRequest = [System.Net.FtpWebRequest]::Create($Uri)
        $FtpWebRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $FtpWebRequest.UseBinary = $true

        # Télécharger le fichier
        $FtpWebResponse = $FtpWebRequest.GetResponse()
        $ResponseStream = $FtpWebResponse.GetResponseStream()

        # Sauvegarder le fichier localement
        $FileStream = [System.IO.File]::Create($LocalFilePath)
        $ResponseStream.CopyTo($FileStream)
        $FileStream.Close()
        $FtpWebResponse.Close()

        # Log du succès
        Add-Content -Path $LogPath -Value "$(Get-Date): Téléchargement réussi depuis $Uri"
        Write-Host "[$(Get-Date)] Téléchargement réussi depuis $Uri. Fichier enregistré à $LocalFilePath" -ForegroundColor Green
        return $true
    } catch {
        # Gestion des erreurs
        Add-Content -Path $LogPath -Value "$(Get-Date): Erreur lors du téléchargement FTP: $_"
        Write-Host "[$(Get-Date)] Échec du téléchargement : $_" -ForegroundColor Red
        return $false
    }
}

# Fonction principale
function Main {
    try {
        Write-Host "[$(Get-Date)] Début de l'exécution du script." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Début de l'exécution du script"

        # Lancer le téléchargement FTP
        $DownloadResult = Download-FromFtp `
            -RemoteFilePath $RemoteFilePath `
            -LocalFilePath $LocalFilePath `
            -Server $FtpServer `
            -Username $FtpUsername `
            -Password $FtpPassword

        # Vérifier le résultat et configurer le contenu de l'email
        if ($DownloadResult) {
            $Subject = "Succès : Fichier téléchargé avec succès"
            $Body = @"
Bonjour,

Le fichier a été téléchargé avec succès depuis le serveur FTP.

Détails :
- Serveur : $FtpServer
- Chemin distant : $RemoteFilePath
- Chemin local : $LocalFilePath

Consultez le journal pour plus de détails :
$LogPath

Cordialement,
Votre script FTP
"@
            Write-Host "[$(Get-Date)] Téléchargement réussi, préparation de l'email de confirmation." -ForegroundColor Green
        } else {
            throw "Échec du téléchargement FTP. Consultez les logs pour plus de détails."
        }
    } catch {
        # Gestion des erreurs
        $Subject = "Échec : Problème lors du téléchargement FTP"
        $Body = @"
Bonjour,

Une erreur s'est produite lors du téléchargement FTP.

Détails de l'erreur :
$_

Consultez le journal pour plus de détails :
$LogPath

Cordialement,
Votre script FTP
"@
        Write-Host "[$(Get-Date)] Une erreur s'est produite : $_" -ForegroundColor Red
    } finally {
        # Envoyer un email
        Write-Host "[$(Get-Date)] Envoi de l'email de notification..." -ForegroundColor Cyan
        Send-Notification -To $AdminEmail -Subject $Subject -Body $Body
        Write-Host "[$(Get-Date)] Script terminé. Consultez les logs pour plus d'informations." -ForegroundColor Cyan
    }
}

# Exécuter le script principal
Main

