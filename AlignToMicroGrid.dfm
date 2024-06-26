object Form_PlaceSilk: TForm_PlaceSilk
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Align To Micro Grid'
  ClientHeight = 434
  ClientWidth = 473
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = Form_PlaceSilkClose
  OnCreate = Form_PlaceSilkCreate
  PixelsPerInch = 96
  TextHeight = 13
  object lblCmpOutLayer: TLabel
    Left = 16
    Top = 196
    Width = 126
    Height = 13
    Caption = 'Component Outline Layer:'
    Visible = False
  end
  object RotationStrategyLbl: TLabel
    Left = 16
    Top = 264
    Width = 90
    Height = 13
    Caption = 'Rotation Strategy:'
    Visible = False
  end
  object PositionDeltaLbl: TLabel
    Left = 226
    Top = 344
    Width = 65
    Height = 13
    Caption = 'Position Delta'
  end
  object Label2: TLabel
    Left = 226
    Top = 196
    Width = 24
    Height = 13
    Caption = 'Kind:'
  end
  object HintLbl: TLabel
    Left = 136
    Top = 412
    Width = 183
    Height = 13
    Caption = 'HALT EXECUTION: Ctrl + Pause/Break'
    Visible = False
  end
  object RG_Filter: TRadioGroup
    Left = 16
    Top = 16
    Width = 149
    Height = 72
    Caption = 'Filter Options'
    ItemIndex = 0
    Items.Strings = (
      'Place Entire Board'
      'Place Selected')
    TabOrder = 0
  end
  object RG_Failures: TRadioGroup
    Left = 16
    Top = 95
    Width = 185
    Height = 91
    Caption = 'Failed Placement Options'
    ItemIndex = 0
    Items.Strings = (
      'Center Over Components'
      'Place Off Board (Bottom Left)'
      'Restore Original')
    TabOrder = 2
    Visible = False
  end
  object GB_AllowUnder: TGroupBox
    Left = 224
    Top = 16
    Width = 216
    Height = 168
    Caption = 'Allow Silk Under Specified Components'
    TabOrder = 1
    Visible = False
    object MEM_AllowUnder: TMemo
      Left = 11
      Top = 27
      Width = 185
      Height = 109
      Lines.Strings = (
        'MEM_AllowUnder')
      TabOrder = 0
      Visible = False
    end
  end
  object BTN_Run: TButton
    Left = 367
    Top = 383
    Width = 75
    Height = 25
    Caption = 'Run'
    TabOrder = 3
    OnClick = BTN_RunClick
  end
  object ProgressBar1: TProgressBar
    Left = 12
    Top = 385
    Width = 340
    Height = 22
    TabOrder = 4
  end
  object cbCmpOutlineLayer: TComboBox
    Left = 15
    Top = 214
    Width = 193
    Height = 21
    TabOrder = 5
    Text = 'cbCmpOutlineLayer'
    Visible = False
  end
  object chkAvoidVias: TCheckBox
    Left = 15
    Top = 242
    Width = 97
    Height = 17
    Caption = 'Avoid VIAs'
    Checked = True
    State = cbChecked
    TabOrder = 6
    Visible = False
  end
  object RotationStrategyCb: TComboBox
    Left = 16
    Top = 282
    Width = 193
    Height = 21
    Style = csDropDownList
    ItemIndex = 5
    TabOrder = 7
    Text = 'KLC Style'
    Visible = False
    Items.Strings = (
      'Component Rotation'
      'Horizontal Rotation'
      'Along Side'
      'Along Axel'
      'Along Pins'
      'KLC Style')
  end
  object FixedSizeChk: TCheckBox
    Left = 16
    Top = 336
    Width = 64
    Height = 17
    Caption = 'Fixed Size'
    Checked = True
    State = cbChecked
    TabOrder = 8
    Visible = False
  end
  object FixedSizeEdt: TEdit
    Left = 96
    Top = 336
    Width = 113
    Height = 21
    TabOrder = 9
    Text = '0.8mm'
    Visible = False
  end
  object FixedWidthChk: TCheckBox
    Left = 16
    Top = 360
    Width = 80
    Height = 17
    Caption = 'Fixed Width'
    Checked = True
    State = cbChecked
    TabOrder = 10
    Visible = False
  end
  object FixedWidthEdt: TEdit
    Left = 96
    Top = 360
    Width = 113
    Height = 21
    TabOrder = 11
    Text = '0.15mm'
    Visible = False
  end
  object PositionDeltaEdt: TEdit
    Left = 226
    Top = 360
    Width = 214
    Height = 21
    TabOrder = 12
    Text = '0.01'
  end
  object PositionsClb: TCheckListBox
    Left = 226
    Top = 212
    Width = 214
    Height = 120
    ItemHeight = 13
    Items.Strings = (
      'TopCenter'
      'CenterRight'
      'BottomCenter'
      'CenterLeft'
      'TopLeft'
      'TopRight'
      'BottomLeft'
      'BottomRight')
    TabOrder = 13
  end
  object TryAlteredRotationChk: TCheckBox
    Left = 16
    Top = 312
    Width = 120
    Height = 17
    Caption = 'Try Altered Rotation'
    Checked = True
    State = cbChecked
    TabOrder = 14
    Visible = False
  end
end
