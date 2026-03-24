const mongoose = require('mongoose');

const costEntrySchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    type: {
      type: String,
      enum: ['daily', 'monthly'],
      required: true
    },
    amount: {
      type: Number,
      required: true,
      min: 0
    },
    currency: {
      type: String,
      default: 'BDT'
    },
    note: {
      type: String,
      default: '',
      maxlength: 500
    },
    date: {
      type: Date,
      default: Date.now,
      index: true
    }
  },
  { timestamps: true }
);

costEntrySchema.index({ user: 1, type: 1, date: -1 });

module.exports = mongoose.model('CostEntry', costEntrySchema);
