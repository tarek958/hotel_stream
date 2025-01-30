const mongoose = require('mongoose');

const hotelSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  location: {
    type: String,
    required: true
  },
  channels: [{
    name: {
      type: String,
      required: true
    },
    description: {
      type: String
    },
    category: {
      type: String,
      required: true
    },
    thumbnail: {
      type: String,
      required: true
    },
    streamUrl: {
      type: String,
      required: true
    },
    isLive: {
      type: Boolean,
      default: true
    }
  }],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Update the updatedAt timestamp before saving
hotelSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('Hotel', hotelSchema);
