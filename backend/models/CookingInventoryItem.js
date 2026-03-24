const mongoose = require('mongoose');

const cookingInventoryItemSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120
    },
    quantity: {
      type: Number,
      default: 1,
      min: 0
    },
    unit: {
      type: String,
      default: 'default'
    },
    grams: {
      type: Number,
      default: 100,
      min: 0
    },
    cost: {
      type: Number,
      default: 0,
      min: 0
    },
    currency: {
      type: String,
      default: 'BDT'
    },
    boughtAt: {
      type: Date,
      default: Date.now
    },
    expiryAt: {
      type: Date
    },
    source: {
      type: String,
      enum: ['manual', 'voice', 'ocr'],
      default: 'manual'
    }
  },
  { timestamps: true }
);

cookingInventoryItemSchema.index({ user: 1, expiryAt: 1 });
cookingInventoryItemSchema.index({ user: 1, name: 1 });

module.exports = mongoose.model('CookingInventoryItem', cookingInventoryItemSchema);
