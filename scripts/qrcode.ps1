# https://powershell.one/res/modules/qrcodegenerator
# https://techexpert.tips/powershell/powershell-creating-qr-code-url/
Install-Module -Name QRCodeGenerator
Import-Module QRCodeGenerator
Add-Type -assembly System.Windows.Forms

$qr_base_form = New-Object System.Windows.Forms.Form
$qr_base_form.Height = 150
$qr_base_form.Width = 350
$qr_base_form.Text = "QR Code Generator"
$qr_base_form.AutoSize = $true

$qr_label_url = New-Object System.Windows.Forms.Label
$qr_label_url.Location = '10,10'
$qr_label_url.Size = '100,15'
$qr_label_url.Text = "URL:"

$qr_input_url = New-Object System.Windows.Forms.TextBox
$qr_input_url.Location = '10,30'
$qr_input_url.Size = '100,25'

$qr_label_name = New-Object System.Windows.Forms.Label
$qr_label_name.Location = '10,70'
$qr_label_name.Size = '100,15'
$qr_label_name.Text = "Name:"

$qr_input_name = New-Object System.Windows.Forms.TextBox
$qr_input_name.Location = '10,90'
$qr_input_name.Size = '100,25'

$qr_png_viewer = New-Object System.Windows.Forms.PictureBox
$qr_png_viewer.Image = $img
$qr_png_viewer.SizeMode = "Autosize"
$qr_png_viewer.Anchor = "Bottom, left"
$qr_png_viewer.Location = '150,10'

$qr_button_create = New-Object System.Windows.Forms.Button
$qr_button_create.Location = '150,150'
$qr_button_create.Size = '100,25'
$qr_button_create.Text = "Create Code"
$qr_button_create.Add_Click({

$path = "c:\IT_folder\" + "$name"+ ".jpg"
$urllink = $qr_input_url.Text
$name = $qr_input_name.Text

New-PSOneQRCodeURI -URI "$urllink" -Width 15 -OutPath "$path"

$img = $path
})

$qr_base_form.Controls.Add($qr_label_url)
$qr_base_form.Controls.Add($qr_input_url)
$qr_base_form.Controls.Add($qr_label_name)
$qr_base_form.Controls.Add($qr_input_name)
$qr_base_form.Controls.Add($qr_png_viewer)
$qr_base_form.Controls.Add($qr_button_create)

$qr_base_form.ShowDialog()
