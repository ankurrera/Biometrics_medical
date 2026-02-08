#!/usr/bin/env bash

# DiDIt KYC Edge Function Deployment Script
# This script helps deploy the didit-kyc Edge Function to Supabase

set -e  # Exit on error

echo "🚀 DiDIt KYC Edge Function Deployment"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}Error: Supabase CLI is not installed.${NC}"
    echo ""
    echo "Please install it first:"
    echo "  npm install -g supabase"
    echo "or"
    echo "  brew install supabase/tap/supabase"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Supabase CLI found${NC}"
echo ""

# Check if user is logged in
if ! supabase projects list &> /dev/null; then
    echo -e "${YELLOW}You need to login to Supabase first.${NC}"
    echo ""
    supabase login
    echo ""
fi

echo -e "${GREEN}✓ Logged in to Supabase${NC}"
echo ""

# Check if project is linked
if [ ! -f ".supabase/config.toml" ]; then
    echo -e "${YELLOW}Project not linked yet.${NC}"
    echo ""
    echo "Available projects:"
    supabase projects list
    echo ""
    read -p "Enter your project reference ID: " PROJECT_REF
    echo ""
    supabase link --project-ref "$PROJECT_REF"
    echo ""
fi

echo -e "${GREEN}✓ Project linked${NC}"
echo ""

# Check environment variables
echo "Checking environment variables..."
echo ""
echo -e "${YELLOW}Important: Make sure you have set these environment variables in Supabase:${NC}"
echo "  - DIDIT_APP_ID"
echo "  - DIDIT_API_KEY"
echo ""
echo "To set them:"
echo "  1. Go to your Supabase Dashboard"
echo "  2. Navigate to Settings → Edge Functions"
echo "  3. Add the environment variables"
echo ""
read -p "Have you set the environment variables? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Please set the environment variables first and then run this script again.${NC}"
    exit 1
fi

echo ""
echo "Deploying didit-kyc Edge Function..."
echo ""

# Deploy the function
supabase functions deploy didit-kyc

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Test the function:"
echo "     supabase functions serve didit-kyc"
echo ""
echo "  2. View logs:"
echo "     Check your Supabase Dashboard → Edge Functions → didit-kyc"
echo ""
echo "  3. Test with your Flutter app:"
echo "     Run the app and try the KYC verification flow"
echo ""
echo "  4. Monitor for errors:"
echo "     Keep an eye on the logs for any issues"
echo ""
echo -e "${GREEN}🎉 All done!${NC}"
