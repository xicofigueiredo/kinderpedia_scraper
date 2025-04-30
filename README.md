# Kinderpedia Document Scraper

A Ruby on Rails application that downloads both private and public documents from Kinderpedia for a specific child.

## Features

- Downloads both private and public documents
- Authenticates using JWT tokens
- Creates a ZIP file with all downloaded documents
- Simple web interface for document downloading

## Requirements

- Ruby 3.1.2
- Rails 7.1.5
- Bundler

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/kinderpedia_scraper.git
cd kinderpedia_scraper
```

2. Install dependencies:
```bash
bundle install
```

3. Set up environment variables:
Create a `.env` file in the root directory with:
