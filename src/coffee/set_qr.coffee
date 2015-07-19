
$ ->
  ### controller QR code の設置 ###
  ($ '#qr').qrcode
    width: 100
    height: 100
    text: location.href + "con"
