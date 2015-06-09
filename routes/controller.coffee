express = require('express')
router = express.Router()

### GET home page. ###

router.get '/', (req, res, next) ->
  title = 'えるとぅーん コントローラー'
  console.log(req.query.type? )
  console.log(req.query.team? )
  if !req.query.type? or !req.query.team?
    res.render 'select',
      title: title
    return
  res.render 'controller',
    title: title
    controller_js: 'sub'
  return

module.exports = router
