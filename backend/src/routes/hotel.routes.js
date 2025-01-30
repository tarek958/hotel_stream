const express = require('express');
const router = express.Router();
const hotelController = require('../controllers/hotel.controller');

// Hotel routes
router.get('/hotels', hotelController.getAllHotels);
router.get('/hotels/:hotelId', hotelController.getHotelInfo);
router.post('/hotels', hotelController.createHotel);
router.put('/hotels/:hotelId', hotelController.updateHotel);

// Channel routes
router.post('/hotels/:hotelId/channels', hotelController.addChannel);
router.put('/hotels/:hotelId/channels/:channelId', hotelController.updateChannel);
router.delete('/hotels/:hotelId/channels/:channelId', hotelController.deleteChannel);

module.exports = router;
