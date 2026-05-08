/**
 * Server-side validation utilities
 */

export class Validator {
  static email(value) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(value);
  }

  static phone(value) {
    // Supports common formats: 1234567890, (123)456-7890, +1-123-456-7890
    const re = /^[+]?[(]?[0-9]{3}[)]?[-\s.]?[0-9]{3}[-\s.]?[0-9]{4,6}$/;
    return re.test(value);
  }

  static required(value) {
    return value !== null && value !== undefined && String(value).trim().length > 0;
  }

  static minLength(value, min) {
    return String(value).length >= min;
  }

  static maxLength(value, max) {
    return String(value).length <= max;
  }

  static isNumber(value) {
    return !Number.isNaN(Number(value));
  }

  static min(value, min) {
    return Number(value) >= min;
  }

  static max(value, max) {
    return Number(value) <= max;
  }

  static isImageMime(mimeType) {
    return mimeType && mimeType.startsWith('image/');
  }

  static cropName(value) {
    if (!this.required(value)) return false;
    if (!this.minLength(value, 2)) return false;
    if (!this.maxLength(value, 50)) return false;
    // Allow Unicode letters (Urdu, Arabic, etc.), digits, spaces, hyphens
    return /^[\p{L}\p{N}\s-]+$/u.test(value);
  }

  static district(value) {
    if (!this.required(value)) return false;
    if (!this.minLength(value, 2)) return false;
    if (!this.maxLength(value, 50)) return false;
    // Allow Unicode letters (Urdu, Arabic, etc.), digits, spaces, hyphens
    return /^[\p{L}\p{N}\s-]+$/u.test(value);
  }

  static quantity(value) {
    if (!this.isNumber(value)) return false;
    return this.min(value, 0.1) && this.max(value, 999999);
  }

  static price(value) {
    if (!this.isNumber(value)) return false;
    return this.min(value, 0.01) && this.max(value, 999999);
  }
}

export const validateListingInput = (data) => {
  const errors = {};

  if (!Validator.required(data.cropName)) {
    errors.cropName = 'Crop name is required';
  } else if (!Validator.cropName(data.cropName)) {
    errors.cropName = 'Crop name must be 2-50 alphanumeric characters';
  }

  if (!Validator.required(data.district)) {
    errors.district = 'District is required';
  } else if (!Validator.district(data.district)) {
    errors.district = 'District must be 2-50 alphanumeric characters';
  }

  if (!Validator.required(data.quantity)) {
    errors.quantity = 'Quantity is required';
  } else if (!Validator.quantity(data.quantity)) {
    errors.quantity = 'Quantity must be between 0.1 and 999999';
  }

  if (!Validator.required(data.askingPrice)) {
    errors.askingPrice = 'Asking price is required';
  } else if (!Validator.price(data.askingPrice)) {
    errors.askingPrice = 'Asking price must be between 0.01 and 999999';
  }

  return Object.keys(errors).length > 0 ? errors : null;
};

export const validateOfferInput = (data) => {
  const errors = {};

  if (!Validator.required(data.listingId)) {
    errors.listingId = 'Listing ID is required';
  }

  if (!Validator.required(data.offerPrice)) {
    errors.offerPrice = 'Offer price is required';
  } else if (!Validator.price(data.offerPrice)) {
    errors.offerPrice = 'Offer price must be valid';
  }

  if (!Validator.required(data.quantity)) {
    errors.quantity = 'Quantity is required';
  } else if (!Validator.quantity(data.quantity)) {
    errors.quantity = 'Quantity must be valid';
  }

  return Object.keys(errors).length > 0 ? errors : null;
};
