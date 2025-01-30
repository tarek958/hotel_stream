const Hotel = require('../models/hotel.model');

// Get hotel information and channels
exports.getHotelInfo = async (req, res) => {
  try {
    const { hotelId } = req.params;
    const hotel = await Hotel.findById(hotelId);
    
    if (!hotel) {
      return res.status(404).json({ message: 'Hotel not found' });
    }

    res.json(hotel);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching hotel information', error: error.message });
  }
};

// Get all hotels (basic info only)
exports.getAllHotels = async (req, res) => {
  try {
    const hotels = await Hotel.find({}, 'name location');
    res.json(hotels);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching hotels', error: error.message });
  }
};

// Add a new hotel
exports.createHotel = async (req, res) => {
  try {
    const hotel = new Hotel(req.body);
    await hotel.save();
    res.status(201).json(hotel);
  } catch (error) {
    res.status(400).json({ message: 'Error creating hotel', error: error.message });
  }
};

// Update hotel information
exports.updateHotel = async (req, res) => {
  try {
    const { hotelId } = req.params;
    const hotel = await Hotel.findByIdAndUpdate(hotelId, req.body, { 
      new: true,
      runValidators: true 
    });
    
    if (!hotel) {
      return res.status(404).json({ message: 'Hotel not found' });
    }

    res.json(hotel);
  } catch (error) {
    res.status(400).json({ message: 'Error updating hotel', error: error.message });
  }
};

// Add a channel to a hotel
exports.addChannel = async (req, res) => {
  try {
    const { hotelId } = req.params;
    const hotel = await Hotel.findById(hotelId);
    
    if (!hotel) {
      return res.status(404).json({ message: 'Hotel not found' });
    }

    hotel.channels.push(req.body);
    await hotel.save();
    res.status(201).json(hotel);
  } catch (error) {
    res.status(400).json({ message: 'Error adding channel', error: error.message });
  }
};

// Update a channel
exports.updateChannel = async (req, res) => {
  try {
    const { hotelId, channelId } = req.params;
    const hotel = await Hotel.findById(hotelId);
    
    if (!hotel) {
      return res.status(404).json({ message: 'Hotel not found' });
    }

    const channelIndex = hotel.channels.findIndex(
      channel => channel._id.toString() === channelId
    );

    if (channelIndex === -1) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    hotel.channels[channelIndex] = {
      ...hotel.channels[channelIndex].toObject(),
      ...req.body
    };

    await hotel.save();
    res.json(hotel);
  } catch (error) {
    res.status(400).json({ message: 'Error updating channel', error: error.message });
  }
};

// Delete a channel
exports.deleteChannel = async (req, res) => {
  try {
    const { hotelId, channelId } = req.params;
    const hotel = await Hotel.findById(hotelId);
    
    if (!hotel) {
      return res.status(404).json({ message: 'Hotel not found' });
    }

    hotel.channels = hotel.channels.filter(
      channel => channel._id.toString() !== channelId
    );

    await hotel.save();
    res.json(hotel);
  } catch (error) {
    res.status(400).json({ message: 'Error deleting channel', error: error.message });
  }
};
