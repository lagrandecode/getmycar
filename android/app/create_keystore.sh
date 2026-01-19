#!/bin/bash

# Script to create Android release keystore
# This will prompt you for all required information

echo "=========================================="
echo "Creating Android Release Keystore"
echo "=========================================="
echo ""
echo "You'll be asked for:"
echo "1. Keystore password (choose a strong password - save it!)"
echo "2. Key password (can be same as keystore password)"
echo "3. Your name/organization details"
echo ""
echo "IMPORTANT: Answer 'yes' when asked if the information is correct!"
echo ""

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if [ -f "upload-keystore.jks" ]; then
    echo ""
    echo "✅ Keystore created successfully!"
    echo "📁 Location: android/app/upload-keystore.jks"
    echo ""
    echo "⚠️  IMPORTANT: Save your passwords securely!"
    echo "   You'll need them to create key.properties file."
else
    echo ""
    echo "❌ Keystore creation failed. Please try again."
fi
