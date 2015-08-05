
$ ->
  ### controller QR code の設置 ###
  # GET パラメータを除いたURL + コントローラのパス
  url = location.href.replace(location.search, "") + "con"
  console.log("setQR: " + url)
  ($ '#qr').qrcode
    width: 100
    height: 100
    text: url
