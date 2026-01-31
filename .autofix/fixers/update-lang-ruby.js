#!/usr/bin/env node

/**
 * AutoFix fixer for updating Ruby versions in lang-ruby chunk
 * 
 * This fixer updates the RUBY_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable version of Ruby.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_RUBY_DIR = path.join(__dirname, '../../chunks/lang-ruby');
const DOCKERFILE = path.join(LANG_RUBY_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_RUBY_DIR, 'Dockerfile.build.ubi8');
const RUBY_VERSIONS_URL = 'https://api.github.com/repos/ruby/ruby/releases';
const CACHE_FILE = path.join(__dirname, '.ruby-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest Ruby version (fallback if API fails)
const FALLBACK_RUBY_VERSION = '3.3.0';

/**
 * Fetch Ruby versions from GitHub API with caching
 * @returns {Promise<string[]>} Array of stable Ruby versions
 */
async function fetchRubyVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached Ruby versions');
        return cachedData.versions;
      }
    }

    console.log('Fetching latest Ruby versions from GitHub...');
    const response = await fetch(RUBY_VERSIONS_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    const versions = data
      .filter(release => !release.prerelease && !release.draft && 
        (release.tag_name.startsWith('v') || release.tag_name.startsWith('_')))
      .map(release => {
        const tag = release.tag_name;
        // Extract version number from tags like "v3.3.0" or "_3_3_0"
        if (tag.startsWith('v')) {
          return tag.substring(1);
        } else if (tag.startsWith('_')) {
          return tag.replace(/_/g, '.');
        }
        return tag;
      })
      .filter(version => /^\d+\.\d+(\.\d+)?$/.test(version))
      .sort((a, b) => {
        const aParts = a.split('.').map(Number);
        const bParts = b.split('.').map(Number);
        for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
          const aPart = aParts[i] || 0;
          const bPart = bParts[i] || 0;
          if (aPart !== bPart) return bPart - aPart;
        }
        return 0;
      })
      .slice(0, 20); // Get top 20 latest stable versions
    
    // Cache the results
    await fs.writeFile(CACHE_FILE, JSON.stringify({
      versions,
      timestamp: Date.now()
    }), 'utf8');
    
    console.log(`Found ${versions.length} stable Ruby versions`);
    return versions;
  } catch (error) {
    console.warn('Failed to fetch Ruby versions, using fallback:', error.message);
    return [FALLBACK_RUBY_VERSION];
  }
}

exports.register = async (fixers) => {
  const versions = await fetchRubyVersions();
  
  // Register fixer for each stable version
  versions.forEach(version => {
    fixers.register({
      name: `update-ruby-${version}`,
      description: `Update Ruby version to ${version}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updateRubyVersionInFile(DOCKERFILE, version),
          updateRubyVersionInFile(DOCKERFILE_BUILD_UBI8, version)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update Ruby version in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newVersion - New Ruby version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updateRubyVersionInFile(filePath, newVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /RUBY_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);

    if (!match) {
      console.warn(`RUBY_VERSION not found in ${filePath}`);
      return false;
    }

    const currentVersion = match[1];
    if (currentVersion === newVersion) {
      console.log(`Ruby version already up-to-date in ${filePath}: ${newVersion}`);
      return false;
    }

    // Create backup before making changes
    const backupPath = `${filePath}.backup.${Date.now()}`;
    await fs.writeFile(backupPath, content, 'utf8');
    
    const updatedContent = content.replace(versionRegex, (matchStr) => {
      // Preserve the original format (with or without quotes, with or without spaces)
      const hasQuotes = matchStr.includes('"');
      const hasEquals = matchStr.includes('=');
      const hasSpaces = matchStr.includes(' ');
      
      if (hasQuotes) {
        return matchStr.replace(currentVersion, newVersion);
      } else if (hasEquals && !hasSpaces) {
        return `RUBY_VERSION=${newVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `RUBY_VERSION= ${newVersion}`;
      } else {
        return `RUBY_VERSION ${newVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated Ruby version in ${filePath}: ${currentVersion} -> ${newVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate Ruby version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateRubyVersion(version) {
  return /^\d+\.\d+(\.\d+)?$/.test(version);
}

/**
 * Get current Ruby version from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<string|null>} - Current version or null if not found
 */
async function getCurrentVersion(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /RUBY_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);
    return match ? match[1] : null;
  } catch (error) {
    return null;
  }
}

/**
 * Main function with enhanced error handling
 */
async function main() {
  try {
    console.log('Updating Ruby versions in lang-ruby chunk...');
    
    // Get latest version
    const versions = await fetchRubyVersions();
    const latestVersion = versions[0];
    
    if (!validateRubyVersion(latestVersion)) {
      throw new Error(`Invalid Ruby version format: ${latestVersion}`);
    }
    
    console.log(`Target Ruby version: ${latestVersion}`);
    
    // Check current versions
    const currentVersions = await Promise.all([
      getCurrentVersion(DOCKERFILE),
      getCurrentVersion(DOCKERFILE_BUILD_UBI8)
    ]);
    
    console.log('Current versions:');
    console.log(`  ${path.basename(DOCKERFILE)}: ${currentVersions[0] || 'not found'}`);
    console.log(`  ${path.basename(DOCKERFILE_BUILD_UBI8)}: ${currentVersions[1] || 'not found'}`);
    
    // Update files in parallel
    const results = await Promise.allSettled([
      updateRubyVersionInFile(DOCKERFILE, latestVersion),
      updateRubyVersionInFile(DOCKERFILE_BUILD_UBI8, latestVersion)
    ]);
    
    const updated = results.some(result => 
      result.status === 'fulfilled' && result.value
    );
    
    // Check for any errors
    const errors = results
      .filter(result => result.status === 'rejected')
      .map(result => result.reason);
    
    if (errors.length > 0) {
      console.error('Some operations failed:');
      errors.forEach(error => console.error(`  - ${error.message}`));
    }
    
    if (updated) {
      console.log('\nRuby version update completed successfully!');
      console.log('Please rebuild the lang-ruby images to use the new version.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - Ruby versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during Ruby version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updateRubyVersionInFile,
  fetchRubyVersions,
  getCurrentVersion,
  validateRubyVersion,
  FALLBACK_RUBY_VERSION
};
