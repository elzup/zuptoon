express = require('express')
router = express.Router()

### GET home page. ###

# ノーマルコントローラー
router.get '/', (req, res, next) ->
  res.render 'controller',
    title: 'えるとぅーん コントローラー'
    controller_js: 'sub'
  return

# ふるふるコントローラー
router.get '/ff', (req, res, next) ->
  res.render 'controller',
    title: 'えるとぅーん ふるふるコントローラー'
    controller_js: 'sub_shake'
  return

module.exports = router
