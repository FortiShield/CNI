#!/usr/bin/env node

/**
 * AutoFix fixer for updating Elixir versions in lang-elixir chunk
 * 
 * This fixer updates the ELIXIR_VERSION and OTP_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable versions of Elixir and OTP.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_ELIXIR_DIR = path.join(__dirname, '../../chunks/lang-elixir');
const DOCKERFILE = path.join(LANG_ELIXIR_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_ELIXIR_DIR, 'Dockerfile.build.ubi8');
const ELIXIR_VERSIONS_URL = 'https://api.github.com/repos/elixir-lang/elixir/releases';
const OTP_VERSIONS_URL = 'https://api.github.com/repos/erlang/otp/releases';
const CACHE_FILE = path.join(__dirname, '.elixir-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest Elixir and OTP versions (fallback if API fails)
const FALLBACK_ELIXIR_VERSION = '1.16.1';
const FALLBACK_OTP_VERSION = '26.2.1';

/**
 * Fetch Elixir and OTP versions from GitHub API with caching
 * @returns {Promise<{elixir: string[], otp: string[]}>} Arrays of stable versions
 */
async function fetchElixirVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached Elixir versions');
        return cachedData;
      }
    }

    console.log('Fetching latest Elixir and OTP versions from GitHub...');
    
    // Fetch both Elixir and OTP versions in parallel
    const [elixirResponse, otpResponse] = await Promise.all([
      fetch(ELIXIR_VERSIONS_URL),
      fetch(OTP_VERSIONS_URL)
    ]);
    
    if (!elixirResponse.ok) {
      throw new Error(`Elixir HTTP ${elixirResponse.status}: ${elixirResponse.statusText}`);
    }
    if (!otpResponse.ok) {
      throw new Error(`OTP HTTP ${otpResponse.status}: ${otpResponse.statusText}`);
    }
    
    const [elixirData, otpData] = await Promise.all([
      elixirResponse.json(),
      otpResponse.json()
    ]);
    
    // Process Elixir versions
    const elixirVersions = elixirData
      .filter(release => !release.prerelease && !release.draft && 
        release.tag_name.startsWith('v'))
      .map(release => release.tag_name.substring(1))
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
      .slice(0, 20);
    
    // Process OTP versions
    const otpVersions = otpData
      .filter(release => !release.prerelease && !release.draft && 
        release.tag_name.startsWith('OTP-'))
      .map(release => release.tagName.replace('OTP-', ''))
      .filter(version => /^\d+(\.\d+)?$/.test(version))
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
      .slice(0, 20);
    
    const result = {
      elixir: elixirVersions,
      otp: otpVersions,
      timestamp: Date.now()
    };
    
    // Cache the results
    await fs.writeFile(CACHE_FILE, JSON.stringify(result), 'utf8');
    
    console.log(`Found ${elixirVersions.length} Elixir versions and ${otpVersions.length} OTP versions`);
    return result;
  } catch (error) {
    console.warn('Failed to fetch Elixir/OTP versions, using fallback:', error.message);
    return {
      elixir: [FALLBACK_ELIXIR_VERSION],
      otp: [FALLBACK_OTP_VERSION]
    };
  }
}

exports.register = async (fixers) => {
  const versions = await fetchElixirVersions();
  
  // Register fixer for each Elixir version (paired with latest OTP)
  versions.elixir.forEach(elixirVersion => {
    const latestOtpVersion = versions.otp[0];
    fixers.register({
      name: `update-elixir-${elixirVersion}`,
      description: `Update Elixir version to ${elixirVersion} with OTP ${latestOtpVersion}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updateElixirVersionInFile(DOCKERFILE, elixirVersion, latestOtpVersion),
          updateElixirVersionInFile(DOCKERFILE_BUILD_UBI8, elixirVersion, latestOtpVersion)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update Elixir and OTP versions in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newElixirVersion - New Elixir version to set
 * @param {string} newOtpVersion - New OTP version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updateElixirVersionInFile(filePath, newElixirVersion, newOtpVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const elixirRegex = /ELIXIR_VERSION[=\s]+"?([^"]+)"?/;
    const otpRegex = /OTP_VERSION[=\s]+"?([^"]+)"?/;
    
    const elixirMatch = content.match(elixirRegex);
    const otpMatch = content.match(otpRegex);

    if (!elixirMatch || !otpMatch) {
      console.warn(`ELIXIR_VERSION or OTP_VERSION not found in ${filePath}`);
      return false;
    }

    const currentElixirVersion = elixirMatch[1];
    const currentOtpVersion = otpMatch[1];
    
    if (currentElixirVersion === newElixirVersion && currentOtpVersion === newOtpVersion) {
      console.log(`Elixir/OTP versions already up-to-date in ${filePath}: Elixir ${newElixirVersion}, OTP ${newOtpVersion}`);
      return false;
    }

    // Create backup before making changes
    const backupPath = `${filePath}.backup.${Date.now()}`;
    await fs.writeFile(backupPath, content, 'utf8');
    
    let updatedContent = content;
    
    // Update Elixir version
    updatedContent = updatedContent.replace(elixirRegex, (matchStr) => {
      const hasQuotes = matchStr.includes('"');
      const hasEquals = matchStr.includes('=');
      const hasSpaces = matchStr.includes(' ');
      
      if (hasQuotes) {
        return matchStr.replace(currentElixirVersion, newElixirVersion);
      } else if (hasEquals && !hasSpaces) {
        return `ELIXIR_VERSION=${newElixirVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `ELIXIR_VERSION= ${newElixirVersion}`;
      } else {
        return `ELIXIR_VERSION ${newElixirVersion}`;
      }
    });
    
    // Update OTP version
    updatedContent = updatedContent.replace(otpRegex, (matchStr) => {
      const hasQuotes = matchStr.includes('"');
      const hasEquals = matchStr.includes('=');
      const hasSpaces = matchStr.includes(' ');
      
      if (hasQuotes) {
        return matchStr.replace(currentOtpVersion, newOtpVersion);
      } else if (hasEquals && !hasSpaces) {
        return `OTP_VERSION=${newOtpVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `OTP_VERSION= ${newOtpVersion}`;
      } else {
        return `OTP_VERSION ${newOtpVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated Elixir/OTP versions in ${filePath}:`);
    console.log(`  Elixir: ${currentElixirVersion} -> ${newElixirVersion}`);
    console.log(`  OTP: ${currentOtpVersion} -> ${newOtpVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate Elixir version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateElixirVersion(version) {
  return /^\d+\.\d+(\.\d+)?$/.test(version);
}

/**
 * Validate OTP version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateOtpVersion(version) {
  return /^\d+(\.\d+)?$/.test(version);
}

/**
 * Get current Elixir and OTP versions from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<{elixir: string|null, otp: string|null}>} - Current versions or null if not found
 */
async function getCurrentVersions(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const elixirRegex = /ELIXIR_VERSION[=\s]+"?([^"]+)"?/;
    const otpRegex = /OTP_VERSION[=\s]+"?([^"]+)"?/;
    const elixirMatch = content.match(elixirRegex);
    const otpMatch = content.match(otpRegex);
    
    return {
      elixir: elixirMatch ? elixirMatch[1] : null,
      otp: otpMatch ? otpMatch[1] : null
    };
  } catch (error) {
    return { elixir: null, otp: null };
  }
}

/**
 * Main function with enhanced error handling
 */
async function main() {
  try {
    console.log('Updating Elixir/OTP versions in lang-elixir chunk...');
    
    // Get latest versions
    const versions = await fetchElixirVersions();
    const latestElixirVersion = versions.elixir[0];
    const latestOtpVersion = versions.otp[0];
    
    if (!validateElixirVersion(latestElixirVersion) || !validateOtpVersion(latestOtpVersion)) {
      throw new Error(`Invalid version format: Elixir ${latestElixirVersion}, OTP ${latestOtpVersion}`);
    }
    
    console.log(`Target versions: Elixir ${latestElixirVersion}, OTP ${latestOtpVersion}`);
    
    // Check current versions
    const currentVersions = await Promise.all([
      getCurrentVersions(DOCKERFILE),
      getCurrentVersions(DOCKERFILE_BUILD_UBI8)
    ]);
    
    console.log('Current versions:');
    console.log(`  ${path.basename(DOCKERFILE)}: Elixir ${currentVersions[0].elixir || 'not found'}, OTP ${currentVersions[0].otp || 'not found'}`);
    console.log(`  ${path.basename(DOCKERFILE_BUILD_UBI8)}: Elixir ${currentVersions[1].elixir || 'not found'}, OTP ${currentVersions[1].otp || 'not found'}`);
    
    // Update files in parallel
    const results = await Promise.allSettled([
      updateElixirVersionInFile(DOCKERFILE, latestElixirVersion, latestOtpVersion),
      updateElixirVersionInFile(DOCKERFILE_BUILD_UBI8, latestElixirVersion, latestOtpVersion)
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
      console.log('\nElixir/OTP version update completed successfully!');
      console.log('Please rebuild the lang-elixir images to use the new versions.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - Elixir/OTP versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during Elixir/OTP version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updateElixirVersionInFile,
  fetchElixirVersions,
  getCurrentVersions,
  validateElixirVersion,
  validateOtpVersion,
  FALLBACK_ELIXIR_VERSION,
  FALLBACK_OTP_VERSION
};
