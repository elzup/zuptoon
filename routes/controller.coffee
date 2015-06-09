express = require('express')
router = express.Router()

### GET home page. ###

router.get '/', (req, res, next) ->
  res.render 'controller', title: 'controller'
  return
module.exports = router
