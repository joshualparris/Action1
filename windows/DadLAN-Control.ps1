# DadLAN-Control.ps1
# v0.2.2: Fleet Grid & Layout Fix
# Read-only Action1 fleet dashboard for Windows.
# Requires PSAction1 1.8+ (tested against 1.9.13).

[CmdletBinding()]
param (
    [switch]$TestMode = $true
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppVersion = "v0.2.2"
$script:EndpointsCache = @()
$script:SelectedEndpointId = $null
$script:DadLANMetadata = @{}
$script:IsUpdatingGrid = $false
$script:GlobalOrgName = "None"
$script:GlobalModVer = "Unknown"
$script:GlobalRefreshTime = "Never"
$script:AutoSavedNeeded = $false

$stateRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "DadLAN" } else { Join-Path $HOME ".dadlan" }
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$script:JsonPath = Join-Path $stateRoot "machines.json"

function Add-DadLANActivity {
    param([string]$Laptop,[string]$Action,[ValidateSet("Info","Success","Warning","Error")][string]$Status,[string]$Details,[string]$Duration = "")
    if (-not $script:lvLog) { return }
    $item = New-Object System.Windows.Forms.ListViewItem((Get-Date).ToString("HH:mm:ss"))
    [void]$item.SubItems.Add($Laptop); [void]$item.SubItems.Add($Action); [void]$item.SubItems.Add($Status); [void]$item.SubItems.Add($Duration); [void]$item.SubItems.Add($Details)
    switch ($Status) { "Success" {$item.ForeColor=[Drawing.Color]::DarkGreen}; "Warning" {$item.ForeColor=[Drawing.Color]::DarkOrange}; "Error" {$item.ForeColor=[Drawing.Color]::Firebrick} }
    $script:lvLog.Items.Insert(0,$item) | Out-Null
    while ($script:lvLog.Items.Count -gt 250) { $script:lvLog.Items.RemoveAt(250) }
}

function Import-DadLANConfig {
    $script:DadLANMetadata = @{}
    if (-not (Test-Path $script:JsonPath)) { Add-DadLANActivity "System" "Load Metadata" "Info" "No local metadata yet. It will be created after the first refresh."; return }
    try {
        $items = @(Get-Content -LiteralPath $script:JsonPath -Raw | ConvertFrom-Json)
        foreach ($item in $items) { if ($item.endpointId) { $script:DadLANMetadata[$item.endpointId] = $item } }
        Add-DadLANActivity "System" "Load Metadata" "Success" "Loaded $($items.Count) records from local app data."
    } catch { Add-DadLANActivity "System" "Load Metadata" "Error" $_.Exception.Message }
}

function Save-DadLANConfig {
    try {
        $items = @($script:DadLANMetadata.Values | Sort-Object laptopNumber,friendlyName)
        $items | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:JsonPath -Encoding UTF8
        Add-DadLANActivity "System" "Save Metadata" "Success" "Saved $($items.Count) records to local app data."
    } catch { Add-DadLANActivity "System" "Save Metadata" "Error" $_.Exception.Message }
}

function Get-DadLANMetadata {
    param($Endpoint)
    $id=[string]$Endpoint.id
    if (-not $script:DadLANMetadata.ContainsKey($id)) {
        $number=""; $role="Unknown"; $protected=$false; $name=[string]$Endpoint.name
        if ($name -match "(?i)Laptop\s*#?\s*0?(\d{1,2})") {
            $n=[int]$Matches[1]; $number=$n.ToString("00")
            if ($n -eq 1) {$role="Controller";$protected=$true} elseif ($n -ge 2 -and $n -le 8) {$role="Worker"} elseif ($n -ge 9 -and $n -le 10) {$role="Legacy Worker"}
        }
        $script:DadLANMetadata[$id]=[pscustomobject]@{laptopNumber=$number;endpointId=$id;friendlyName=$name;role=$role;notes="";protected=$protected}
        $script:AutoSavedNeeded=$true
    }
    return $script:DadLANMetadata[$id]
}

function Get-DadLANHealth { param($Endpoint) if ([string]$Endpoint.status -ne "Connected") { return "Offline" }; return "Healthy" }
function Test-DadLANContains { param([string]$Value,[string]$Search) if ([string]::IsNullOrWhiteSpace($Search)) {return $true}; if ($null -eq $Value){return $false}; return $Value.IndexOf($Search,[StringComparison]::OrdinalIgnoreCase)-ge 0 }
function Get-EndpointProperty { param($Object,[string[]]$Names) foreach($name in $Names){$p=$Object.PSObject.Properties[$name]; if($p -and $null -ne $p.Value){return $p.Value}}; return $null }

$form=New-Object Windows.Forms.Form
$form.Text="DadLAN Command Centre $script:AppVersion"+$(if($TestMode){" [SAFE TEST MODE]"})
$form.StartPosition="CenterScreen"; $form.Size=New-Object Drawing.Size(1500,900); $form.MinimumSize=New-Object Drawing.Size(1100,720); $form.Font=New-Object Drawing.Font("Segoe UI",9); $form.BackColor=[Drawing.Color]::WhiteSmoke

$root=New-Object Windows.Forms.TableLayoutPanel; $root.Dock="Fill"; $root.ColumnCount=1; $root.RowCount=3
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,92)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,190)))
$form.Controls.Add($root)

$header=New-Object Windows.Forms.TableLayoutPanel; $header.Dock="Fill"; $header.BackColor=[Drawing.Color]::White; $header.Padding=New-Object Windows.Forms.Padding(12,8,12,8); $header.ColumnCount=4; $header.RowCount=2
[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,45))); [void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,25))); [void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,145))); [void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,145)))
[void]$header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,55))); [void]$header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,45)))
$root.Controls.Add($header,0,0)

$lblTitle=New-Object Windows.Forms.Label; $lblTitle.Text="DadLAN Command Centre"; $lblTitle.Font=New-Object Drawing.Font("Segoe UI",17,[Drawing.FontStyle]::Bold); $lblTitle.Dock="Fill"; $lblTitle.TextAlign="MiddleLeft"; $header.Controls.Add($lblTitle,0,0)
$lblStatusText=New-Object Windows.Forms.Label; $lblStatusText.Text="Action1: Disconnected`nOrganisation: N/A"; $lblStatusText.Dock="Fill"; $lblStatusText.TextAlign="MiddleRight"; $header.Controls.Add($lblStatusText,1,0); $header.SetRowSpan($lblStatusText,2)
$btnConnect=New-Object Windows.Forms.Button; $btnConnect.Text="Connect"; $btnConnect.Dock="Fill"; $btnConnect.Margin=New-Object Windows.Forms.Padding(6); $btnConnect.BackColor=[Drawing.Color]::LightSteelBlue; $btnConnect.FlatStyle="Flat"; $header.Controls.Add($btnConnect,2,0); $header.SetRowSpan($btnConnect,2)
$btnRefresh=New-Object Windows.Forms.Button; $btnRefresh.Text="Refresh"; $btnRefresh.Dock="Fill"; $btnRefresh.Margin=New-Object Windows.Forms.Padding(6); $btnRefresh.BackColor=[Drawing.Color]::LightGreen; $btnRefresh.FlatStyle="Flat"; $btnRefresh.Enabled=$false; $header.Controls.Add($btnRefresh,3,0); $header.SetRowSpan($btnRefresh,2)
$cards=New-Object Windows.Forms.FlowLayoutPanel; $cards.Dock="Fill"; $cards.FlowDirection="LeftToRight"; $cards.WrapContents=$false; $header.Controls.Add($cards,0,1)
function New-SummaryLabel([string]$text,[Drawing.Color]$color){$l=New-Object Windows.Forms.Label;$l.Text=$text;$l.Font=New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold);$l.ForeColor=$color;$l.AutoSize=$true;$l.Padding=New-Object Windows.Forms.Padding(8,2,16,2);return $l}
$lblCardOnline=New-SummaryLabel "0 ONLINE" ([Drawing.Color]::DarkGreen); $lblCardOffline=New-SummaryLabel "0 OFFLINE" ([Drawing.Color]::DimGray); $lblCardProblems=New-SummaryLabel "0 PROBLEMS" ([Drawing.Color]::DimGray); [void]$cards.Controls.Add($lblCardOnline);[void]$cards.Controls.Add($lblCardOffline);[void]$cards.Controls.Add($lblCardProblems)

$content=New-Object Windows.Forms.TableLayoutPanel; $content.Dock="Fill"; $content.ColumnCount=3; $content.RowCount=1; $content.Margin=New-Object Windows.Forms.Padding(0)
[void]$content.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,220))); [void]$content.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100))); [void]$content.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,390))); $root.Controls.Add($content,0,1)

$left=New-Object Windows.Forms.TableLayoutPanel; $left.Dock="Fill";$left.BackColor=[Drawing.Color]::White;$left.Padding=New-Object Windows.Forms.Padding(8);$left.RowCount=3;$left.ColumnCount=1
[void]$left.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,30)));[void]$left.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,34)));[void]$left.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)));$content.Controls.Add($left,0,0)
$lblFilters=New-Object Windows.Forms.Label;$lblFilters.Text="FLEET FILTERS";$lblFilters.Font=New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold);$lblFilters.Dock="Fill";$lblFilters.TextAlign="MiddleLeft";$left.Controls.Add($lblFilters,0,0)
$txtSearch=New-Object Windows.Forms.TextBox;$txtSearch.Dock="Fill";$txtSearch.Text="Search...";$txtSearch.ForeColor=[Drawing.Color]::Gray;$left.Controls.Add($txtSearch,0,1)
$lstFilters=New-Object Windows.Forms.ListBox;$lstFilters.Dock="Fill";$lstFilters.Font=New-Object Drawing.Font("Segoe UI",10);$lstFilters.IntegralHeight=$false;[void]$lstFilters.Items.AddRange(@("All","Online","Offline","Controller","Workers","Legacy","Problems"));$lstFilters.SelectedIndex=0;$left.Controls.Add($lstFilters,0,2)

$centre=New-Object Windows.Forms.Panel;$centre.Dock="Fill";$centre.BackColor=[Drawing.Color]::White;$centre.Padding=New-Object Windows.Forms.Padding(8);$content.Controls.Add($centre,1,0)
$dataGridView=New-Object Windows.Forms.DataGridView;$dataGridView.Dock="Fill";$dataGridView.ReadOnly=$true;$dataGridView.AllowUserToAddRows=$false;$dataGridView.AllowUserToDeleteRows=$false;$dataGridView.AllowUserToResizeRows=$false;$dataGridView.RowHeadersVisible=$false;$dataGridView.MultiSelect=$true;$dataGridView.SelectionMode="FullRowSelect";$dataGridView.AutoSizeColumnsMode="None";$dataGridView.BackgroundColor=[Drawing.Color]::White;$dataGridView.BorderStyle="FixedSingle";$dataGridView.AlternatingRowsDefaultCellStyle.BackColor=[Drawing.Color]::FromArgb(244,246,248);$centre.Controls.Add($dataGridView)

$right=New-Object Windows.Forms.TableLayoutPanel;$right.Dock="Fill";$right.BackColor=[Drawing.Color]::White;$right.Padding=New-Object Windows.Forms.Padding(10);$right.ColumnCount=1;$right.RowCount=4
[void]$right.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,32)));[void]$right.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)));[void]$right.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,48)));[void]$right.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,48)));$content.Controls.Add($right,2,0)
$lblDetTitle=New-Object Windows.Forms.Label;$lblDetTitle.Text="LAPTOP DETAILS";$lblDetTitle.Font=New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold);$lblDetTitle.Dock="Fill";$right.Controls.Add($lblDetTitle,0,0)
$rtbDetails=New-Object Windows.Forms.RichTextBox;$rtbDetails.Dock="Fill";$rtbDetails.ReadOnly=$true;$rtbDetails.BackColor=[Drawing.Color]::WhiteSmoke;$rtbDetails.BorderStyle="None";$rtbDetails.Text="Select an endpoint to view details.";$right.Controls.Add($rtbDetails,0,1)
$detailButtons=New-Object Windows.Forms.TableLayoutPanel;$detailButtons.Dock="Fill";$detailButtons.ColumnCount=2;$detailButtons.RowCount=1;[void]$detailButtons.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,50)));[void]$detailButtons.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,50)));$right.Controls.Add($detailButtons,0,2)
$btnEditMeta=New-Object Windows.Forms.Button;$btnEditMeta.Text="Edit Metadata";$btnEditMeta.Dock="Fill";$btnEditMeta.Enabled=$false;$detailButtons.Controls.Add($btnEditMeta,0,0)
$btnDiagnostics=New-Object Windows.Forms.Button;$btnDiagnostics.Text="Read Diagnostics";$btnDiagnostics.Dock="Fill";$btnDiagnostics.Enabled=$false;$detailButtons.Controls.Add($btnDiagnostics,1,0)
$lblSafe=New-Object Windows.Forms.Label;$lblSafe.Dock="Fill";$lblSafe.TextAlign="MiddleLeft";$lblSafe.ForeColor=[Drawing.Color]::DarkOrange;$lblSafe.Text=$(if($TestMode){"[Safe Test Mode] Remote changes blocked."}else{"Remote changes are not implemented in v0.2.2."});$right.Controls.Add($lblSafe,0,3)

$activity=New-Object Windows.Forms.TableLayoutPanel;$activity.Dock="Fill";$activity.BackColor=[Drawing.Color]::White;$activity.Padding=New-Object Windows.Forms.Padding(8,4,8,8);$activity.ColumnCount=1;$activity.RowCount=2;[void]$activity.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,28)));[void]$activity.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)));$root.Controls.Add($activity,0,2)
$lblLogTitle=New-Object Windows.Forms.Label;$lblLogTitle.Text="DadLAN Activity";$lblLogTitle.Font=New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold);$lblLogTitle.Dock="Fill";$activity.Controls.Add($lblLogTitle,0,0)
$script:lvLog=New-Object Windows.Forms.ListView;$script:lvLog.Dock="Fill";$script:lvLog.View="Details";$script:lvLog.FullRowSelect=$true;$script:lvLog.GridLines=$true;[void]$script:lvLog.Columns.Add("Time",75);[void]$script:lvLog.Columns.Add("Laptop",125);[void]$script:lvLog.Columns.Add("Action",150);[void]$script:lvLog.Columns.Add("Status",80);[void]$script:lvLog.Columns.Add("Duration",85);[void]$script:lvLog.Columns.Add("Details",800);$activity.Controls.Add($script:lvLog,0,1)

function Update-HeaderStatus{$state=$(if($script:GlobalOrgName-eq"None"){"Disconnected"}else{"Connected"});$lblStatusText.Text="Action1: $state`nOrganisation: $($script:GlobalOrgName) | PSAction1: $($script:GlobalModVer) | Refreshed: $($script:GlobalRefreshTime)"}

function Select-Action1Organization{param($Organizations);$orgList=@($Organizations);if($orgList.Count-eq1){return $orgList[0]};$orgForm=New-Object Windows.Forms.Form;$orgForm.Text="Choose Action1 Organisation";$orgForm.StartPosition="CenterParent";$orgForm.Size=New-Object Drawing.Size(440,180);$combo=New-Object Windows.Forms.ComboBox;$combo.Location=New-Object Drawing.Point(20,25);$combo.Size=New-Object Drawing.Size(380,28);$combo.DropDownStyle="DropDownList";foreach($org in $orgList){$name=Get-EndpointProperty $org @("Org_Name","name","Name");[void]$combo.Items.Add([pscustomobject]@{Name=$name;Object=$org})};$combo.DisplayMember="Name";$combo.SelectedIndex=0;$orgForm.Controls.Add($combo);$ok=New-Object Windows.Forms.Button;$ok.Text="Use Organisation";$ok.Location=New-Object Drawing.Point(260,75);$ok.Size=New-Object Drawing.Size(140,35);$ok.DialogResult="OK";$orgForm.Controls.Add($ok);$orgForm.AcceptButton=$ok;if($orgForm.ShowDialog($form)-ne[Windows.Forms.DialogResult]::OK){return $null};return $combo.SelectedItem.Object}

function Connect-DadLANAction1{
    $credForm=New-Object Windows.Forms.Form;$credForm.Text="Action1 Authentication";$credForm.StartPosition="CenterParent";$credForm.Size=New-Object Drawing.Size(460,220)
    $lblId=New-Object Windows.Forms.Label;$lblId.Text="Client ID:";$lblId.Location=New-Object Drawing.Point(20,20);$credForm.Controls.Add($lblId)
    $txtId=New-Object Windows.Forms.TextBox;$txtId.Location=New-Object Drawing.Point(20,42);$txtId.Size=New-Object Drawing.Size(400,24);if($env:ACTION1_CLIENT_ID){$txtId.Text=$env:ACTION1_CLIENT_ID};$credForm.Controls.Add($txtId)
    $lblSecret=New-Object Windows.Forms.Label;$lblSecret.Text="Client Secret:";$lblSecret.Location=New-Object Drawing.Point(20,78);$credForm.Controls.Add($lblSecret)
    $txtSecret=New-Object Windows.Forms.TextBox;$txtSecret.Location=New-Object Drawing.Point(20,100);$txtSecret.Size=New-Object Drawing.Size(400,24);$txtSecret.UseSystemPasswordChar=$true;$credForm.Controls.Add($txtSecret)
    $ok=New-Object Windows.Forms.Button;$ok.Text="Connect";$ok.Location=New-Object Drawing.Point(320,140);$ok.Size=New-Object Drawing.Size(100,32);$ok.DialogResult="OK";$credForm.Controls.Add($ok);$credForm.AcceptButton=$ok
    if($credForm.ShowDialog($form)-ne[Windows.Forms.DialogResult]::OK){return}
    $clientId=$txtId.Text.Trim();$clientSecret=$txtSecret.Text;$txtSecret.Text=""
    if([string]::IsNullOrWhiteSpace($clientId)-or[string]::IsNullOrWhiteSpace($clientSecret)){[Windows.Forms.MessageBox]::Show($form,"Client ID and Client Secret are required.","DadLAN")|Out-Null;return}
    try{Import-Module PSAction1 -ErrorAction Stop;$script:GlobalModVer=(Get-Module PSAction1).Version.ToString();Set-Action1Region -Region Australia -ErrorAction Stop;Set-Action1Credentials -APIKey $clientId -Secret $clientSecret -ErrorAction Stop;$clientSecret=$null;$orgs=@(Get-Action1Organizations -ErrorAction Stop);if($orgs.Count-eq0){throw"No Action1 organisations were returned."};$selectedOrg=Select-Action1Organization $orgs;if(-not$selectedOrg){throw"Organisation selection cancelled."};$orgId=Get-EndpointProperty $selectedOrg @("Org_ID","id","ID");$orgName=Get-EndpointProperty $selectedOrg @("Org_Name","name","Name");Set-Action1DefaultOrg -Org_ID $orgId -ErrorAction Stop;$script:GlobalOrgName=[string]$orgName;Add-DadLANActivity "System" "Authentication" "Success" "Connected to organisation: $orgName";$btnRefresh.Enabled=$true;Update-DadLANGrid}catch{$clientSecret=$null;$script:GlobalOrgName="None";Add-DadLANActivity "System" "Authentication" "Error" $_.Exception.Message;Update-HeaderStatus;[Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,"Action1 connection failed")|Out-Null}
}

function Update-DadLANDetails{
    if($dataGridView.SelectedRows.Count-ne1){$script:SelectedEndpointId=$null;$rtbDetails.Text=$(if($dataGridView.SelectedRows.Count-gt1){"$($dataGridView.SelectedRows.Count) endpoints selected."}else{"Select an endpoint to view details."});$btnEditMeta.Enabled=$false;$btnDiagnostics.Enabled=$false;return}
    $id=[string]$dataGridView.SelectedRows[0].Cells["ID"].Value;$script:SelectedEndpointId=$id;$ep=$script:EndpointsCache|Where-Object{[string]$_.id-eq$id}|Select-Object -First 1;if(-not$ep){return};$meta=Get-DadLANMetadata $ep;$health=Get-DadLANHealth $ep
    $rtbDetails.Clear();$rtbDetails.SelectionFont=New-Object Drawing.Font("Segoe UI",13,[Drawing.FontStyle]::Bold);$rtbDetails.AppendText("Laptop #$($meta.laptopNumber)`n");$rtbDetails.SelectionFont=New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold);$rtbDetails.AppendText("$($meta.friendlyName)`n`n");if($meta.protected){$rtbDetails.SelectionColor=[Drawing.Color]::DarkOrange;$rtbDetails.SelectionFont=New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold);$rtbDetails.AppendText("PROTECTED CONTROLLER`n`n");$rtbDetails.SelectionColor=[Drawing.Color]::Black};$rtbDetails.SelectionFont=New-Object Drawing.Font("Segoe UI",9);$rtbDetails.AppendText("Health: $health`nRole: $($meta.role)`nStatus: $($ep.status)`nOS: $($ep.OS)`nIP: $($ep.address)`nLast Seen: $($ep.last_seen)`nAgent: $($ep.agent_version)`n`nEndpoint Name:`n$($ep.name)`n`nEndpoint ID:`n$($ep.id)`n`nNotes:`n$($meta.notes)");$btnEditMeta.Enabled=$true;$btnDiagnostics.Enabled=$true
}

function Update-DadLANGrid{
    if($script:GlobalOrgName-eq"None"-or$script:IsUpdatingGrid){return};$script:IsUpdatingGrid=$true;$form.UseWaitCursor=$true
    try{$sw=[Diagnostics.Stopwatch]::StartNew();$script:EndpointsCache=@(Get-Action1Endpoints -ErrorAction Stop);$sw.Stop();$script:GlobalRefreshTime=(Get-Date).ToString("HH:mm:ss");Add-DadLANActivity "System" "Refresh Inventory" "Success" "Fetched $($script:EndpointsCache.Count) endpoints." "$($sw.ElapsedMilliseconds) ms";$script:AutoSavedNeeded=$false;$filter=$(if($lstFilters.SelectedItem){[string]$lstFilters.SelectedItem-replace" \(\d+\)$",""}else{"All"});$search=$(if($txtSearch.Text-eq"Search..."){""}else{$txtSearch.Text.Trim()});$dt=New-Object Data.DataTable;foreach($name in @("Health","Num","Name","Role","Status","OS","IP","Last Seen","Agent Version","ID")){[void]$dt.Columns.Add($name)};$counts=[ordered]@{All=0;Online=0;Offline=0;Controller=0;Workers=0;Legacy=0;Problems=0};foreach($ep in $script:EndpointsCache){$meta=Get-DadLANMetadata $ep;$health=Get-DadLANHealth $ep;$counts.All++;if([string]$ep.status-eq"Connected"){$counts.Online++}else{$counts.Offline++};if($meta.role-eq"Controller"){$counts.Controller++}elseif($meta.role-eq"Worker"){$counts.Workers++}elseif($meta.role-eq"Legacy Worker"){$counts.Legacy++};if($health-ne"Healthy"){$counts.Problems++};if($filter-eq"Online"-and[string]$ep.status-ne"Connected"){continue};if($filter-eq"Offline"-and[string]$ep.status-eq"Connected"){continue};if($filter-eq"Controller"-and$meta.role-ne"Controller"){continue};if($filter-eq"Workers"-and$meta.role-ne"Worker"){continue};if($filter-eq"Legacy"-and$meta.role-ne"Legacy Worker"){continue};if($filter-eq"Problems"-and$health-eq"Healthy"){continue};if($search){$matched=$false;foreach($value in @($meta.laptopNumber,$meta.friendlyName,$meta.role,$ep.name,$ep.address,$ep.OS)){if(Test-DadLANContains ([string]$value) $search){$matched=$true;break}};if(-not$matched){continue}};$row=$dt.NewRow();$row["Health"]=$(if($health-eq"Healthy"){"OK"}else{"OFF"});$row["Num"]=$meta.laptopNumber;$row["Name"]=$meta.friendlyName;$row["Role"]=$(if($meta.protected){"$($meta.role) [Protected]"}else{$meta.role});$row["Status"]=$ep.status;$row["OS"]=$ep.OS;$row["IP"]=$ep.address;$row["Last Seen"]=$ep.last_seen;$row["Agent Version"]=$ep.agent_version;$row["ID"]=$ep.id;[void]$dt.Rows.Add($row)};if($script:AutoSavedNeeded){Save-DadLANConfig};$dataGridView.DataSource=$null;$dataGridView.DataSource=$dt;$dataGridView.Columns["ID"].Visible=$false;$dataGridView.Columns["Health"].Width=60;$dataGridView.Columns["Num"].Width=55;$dataGridView.Columns["Name"].AutoSizeMode="Fill";$dataGridView.Columns["Name"].FillWeight=180;$dataGridView.Columns["Role"].Width=130;$dataGridView.Columns["Status"].Width=90;$dataGridView.Columns["OS"].Width=125;$dataGridView.Columns["IP"].Width=120;$dataGridView.Columns["Last Seen"].Width=145;$dataGridView.Columns["Agent Version"].Width=100;$lblCardOnline.Text="$($counts.Online) ONLINE";$lblCardOffline.Text="$($counts.Offline) OFFLINE";$lblCardProblems.Text="$($counts.Problems) PROBLEMS";$lblCardProblems.ForeColor=$(if($counts.Problems){[Drawing.Color]::DarkOrange}else{[Drawing.Color]::DimGray});$selectedIndex=[Math]::Max(0,$lstFilters.SelectedIndex);$lstFilters.BeginUpdate();try{$lstFilters.Items.Clear();[void]$lstFilters.Items.Add("All ($($counts.All))");[void]$lstFilters.Items.Add("Online ($($counts.Online))");[void]$lstFilters.Items.Add("Offline ($($counts.Offline))");[void]$lstFilters.Items.Add("Controller ($($counts.Controller))");[void]$lstFilters.Items.Add("Workers ($($counts.Workers))");[void]$lstFilters.Items.Add("Legacy ($($counts.Legacy))");[void]$lstFilters.Items.Add("Problems ($($counts.Problems))");$lstFilters.SelectedIndex=[Math]::Min($selectedIndex,$lstFilters.Items.Count-1)}finally{$lstFilters.EndUpdate()};Update-HeaderStatus;Update-DadLANDetails;Add-DadLANActivity "System" "UI Validation" "Info" "Grid rows=$($dt.Rows.Count), visible=$($dataGridView.Visible), size=$($dataGridView.Width)x$($dataGridView.Height)."}catch{Add-DadLANActivity "System" "Refresh Inventory" "Error" $_.Exception.Message;[Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,"Refresh failed")|Out-Null}finally{$form.UseWaitCursor=$false;$script:IsUpdatingGrid=$false}
}

$btnConnect.Add_Click({Connect-DadLANAction1});$btnRefresh.Add_Click({Update-DadLANGrid});$lstFilters.Add_SelectedIndexChanged({if(-not$script:IsUpdatingGrid){Update-DadLANGrid}});$dataGridView.Add_SelectionChanged({Update-DadLANDetails})
$txtSearch.Add_Enter({if($txtSearch.Text-eq"Search..."){$txtSearch.Text="";$txtSearch.ForeColor=[Drawing.Color]::Black}});$txtSearch.Add_Leave({if([string]::IsNullOrWhiteSpace($txtSearch.Text)){$txtSearch.Text="Search...";$txtSearch.ForeColor=[Drawing.Color]::Gray}});$txtSearch.Add_TextChanged({if($txtSearch.Text-ne"Search..."-and-not$script:IsUpdatingGrid-and$script:GlobalOrgName-ne"None"){Update-DadLANGrid}})

$btnEditMeta.Add_Click({if(-not$script:SelectedEndpointId){return};$ep=$script:EndpointsCache|Where-Object{[string]$_.id-eq[string]$script:SelectedEndpointId}|Select-Object -First 1;$meta=Get-DadLANMetadata $ep;$metaForm=New-Object Windows.Forms.Form;$metaForm.Text="Edit Local Metadata";$metaForm.StartPosition="CenterParent";$metaForm.Size=New-Object Drawing.Size(480,360);$layout=New-Object Windows.Forms.TableLayoutPanel;$layout.Dock="Fill";$layout.Padding=New-Object Windows.Forms.Padding(12);$layout.ColumnCount=2;$layout.RowCount=6;[void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,120)));[void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)));$metaForm.Controls.Add($layout);$labels=@("Laptop #:","Friendly Name:","Role:","Protected:","Notes:");for($i=0;$i-lt$labels.Count;$i++){$l=New-Object Windows.Forms.Label;$l.Text=$labels[$i];$l.Dock="Fill";$l.TextAlign="MiddleLeft";$layout.Controls.Add($l,0,$i)};$txtNum=New-Object Windows.Forms.TextBox;$txtNum.Text=$meta.laptopNumber;$txtNum.Dock="Fill";$layout.Controls.Add($txtNum,1,0);$txtName=New-Object Windows.Forms.TextBox;$txtName.Text=$meta.friendlyName;$txtName.Dock="Fill";$layout.Controls.Add($txtName,1,1);$cmbRole=New-Object Windows.Forms.ComboBox;$cmbRole.Items.AddRange(@("Controller","Worker","Legacy Worker","Unknown"));$cmbRole.SelectedItem=$meta.role;$cmbRole.DropDownStyle="DropDownList";$cmbRole.Dock="Fill";$layout.Controls.Add($cmbRole,1,2);$chkProtected=New-Object Windows.Forms.CheckBox;$chkProtected.Checked=$meta.protected;$chkProtected.Text="Exclude from future fleet actions";$chkProtected.Dock="Fill";$layout.Controls.Add($chkProtected,1,3);$txtNotes=New-Object Windows.Forms.TextBox;$txtNotes.Text=$meta.notes;$txtNotes.Multiline=$true;$txtNotes.Dock="Fill";$layout.Controls.Add($txtNotes,1,4);$layout.RowStyles[4].SizeType=[Windows.Forms.SizeType]::Percent;$layout.RowStyles[4].Height=100;$save=New-Object Windows.Forms.Button;$save.Text="Save";$save.DialogResult="OK";$save.Dock="Right";$layout.Controls.Add($save,1,5);$metaForm.AcceptButton=$save;if($metaForm.ShowDialog($form)-eq[Windows.Forms.DialogResult]::OK){$meta.laptopNumber=$txtNum.Text.Trim();$meta.friendlyName=$txtName.Text.Trim();$meta.role=[string]$cmbRole.SelectedItem;$meta.protected=[bool]$chkProtected.Checked;$meta.notes=$txtNotes.Text;Save-DadLANConfig;Update-DadLANGrid}})

$btnDiagnostics.Add_Click({if(-not$script:SelectedEndpointId){return};$ep=$script:EndpointsCache|Where-Object{[string]$_.id-eq[string]$script:SelectedEndpointId}|Select-Object -First 1;try{$sw=[Diagnostics.Stopwatch]::StartNew();$diag=Get-Action1Endpoint -EndpointId $script:SelectedEndpointId -ErrorAction Stop;$sw.Stop();Add-DadLANActivity $ep.name "Read Diagnostics" "Success" "Read-only endpoint details retrieved." "$($sw.ElapsedMilliseconds) ms";$rtbDetails.AppendText("`n`nRAW DIAGNOSTICS`n------------------------------`n");foreach($property in $diag.PSObject.Properties){$rtbDetails.AppendText("$($property.Name): $($property.Value)`n")}}catch{Add-DadLANActivity $ep.name "Read Diagnostics" "Error" $_.Exception.Message}})

$form.Add_Shown({Import-DadLANConfig;Update-HeaderStatus;$form.ActiveControl=$btnConnect})
[void]$form.ShowDialog()
