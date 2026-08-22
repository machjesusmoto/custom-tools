use anyhow::{Context, Result};
use rand::RngCore;
use sha2::{Digest, Sha256};
use std::io::{self, Write};
use zeroize::Zeroize;

/// Secure password container that automatically clears memory
#[derive(Clone)]
pub struct SecurePassword {
    password: Vec<u8>,
}

impl Drop for SecurePassword {
    fn drop(&mut self) {
        self.password.zeroize();
    }
}

impl SecurePassword {
    pub fn new(password: String) -> Self {
        Self {
            password: password.into_bytes(),
        }
    }

    pub fn from_bytes(mut password: Vec<u8>) -> Self {
        let result = Self { password: password.clone() };
        password.zeroize(); // Clear the original
        result
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.password
    }

    pub fn len(&self) -> usize {
        self.password.len()
    }

    pub fn is_empty(&self) -> bool {
        self.password.is_empty()
    }

    /// Generate password hash for verification
    pub fn hash(&self) -> Vec<u8> {
        let mut hasher = Sha256::new();
        hasher.update(&self.password);
        hasher.finalize().to_vec()
    }

    /// Verify password against hash
    pub fn verify_hash(&self, hash: &[u8]) -> bool {
        let computed_hash = self.hash();
        computed_hash == hash
    }
}

impl std::fmt::Debug for SecurePassword {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "SecurePassword[*** {} bytes ***]", self.password.len())
    }
}

/// Secure password input without echo
pub fn read_password(prompt: &str) -> Result<SecurePassword> {
    // For terminal UI, we'll handle this through the UI layer
    // This is a fallback for CLI usage
    print!("{}", prompt);
    io::stdout().flush()?;
    
    let password = rpassword::read_password()
        .context("Failed to read password")?;
    
    Ok(SecurePassword::new(password))
}

/// Generate secure random bytes
pub fn generate_random_bytes(len: usize) -> Vec<u8> {
    let mut bytes = vec![0u8; len];
    rand::thread_rng().fill_bytes(&mut bytes);
    bytes
}

/// Generate a random salt for password-based encryption
pub fn generate_salt() -> [u8; 32] {
    let mut salt = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut salt);
    salt
}

/// Validate password strength
pub struct PasswordStrength {
    pub score: u8, // 0-100
    pub feedback: Vec<String>,
}

pub fn validate_password_strength(password: &SecurePassword) -> PasswordStrength {
    let password_str = String::from_utf8_lossy(password.as_bytes());
    let mut score = 0u8;
    let mut feedback = Vec::new();

    // Length check
    let len = password_str.len();
    if len >= 12 {
        score += 30;
    } else if len >= 8 {
        score += 20;
        feedback.push("Consider using a longer password (12+ characters)".to_string());
    } else {
        feedback.push("Password should be at least 8 characters long".to_string());
    }

    // Character variety
    let has_lower = password_str.chars().any(|c| c.is_lowercase());
    let has_upper = password_str.chars().any(|c| c.is_uppercase());
    let has_digit = password_str.chars().any(|c| c.is_ascii_digit());
    let has_special = password_str.chars().any(|c| !c.is_alphanumeric());

    let variety_count = [has_lower, has_upper, has_digit, has_special]
        .iter()
        .filter(|&&x| x)
        .count();

    match variety_count {
        4 => score += 40,
        3 => {
            score += 30;
            feedback.push("Consider adding more character types".to_string());
        }
        2 => {
            score += 20;
            feedback.push("Use uppercase, lowercase, numbers, and symbols".to_string());
        }
        _ => {
            score += 10;
            feedback.push("Password should include different character types".to_string());
        }
    }

    // Common patterns check
    let common_patterns = ["123", "abc", "password", "qwerty"];
    let lower_password = password_str.to_lowercase();
    
    if common_patterns.iter().any(|&pattern| lower_password.contains(pattern)) {
        score = score.saturating_sub(20);
        feedback.push("Avoid common patterns and dictionary words".to_string());
    } else {
        score += 20;
    }

    // Repetition check
    let mut has_repetition = false;
    for i in 0..password_str.len().saturating_sub(2) {
        let substring = &password_str[i..i+3];
        if password_str[i+3..].contains(substring) {
            has_repetition = true;
            break;
        }
    }

    if has_repetition {
        score = score.saturating_sub(10);
        feedback.push("Avoid repeating patterns".to_string());
    } else {
        score += 10;
    }

    if score >= 80 && feedback.is_empty() {
        feedback.push("Strong password!".to_string());
    } else if score >= 60 {
        feedback.push("Good password strength".to_string());
    } else if score >= 40 {
        feedback.push("Moderate password strength".to_string());
    } else {
        feedback.push("Weak password - consider making it stronger".to_string());
    }

    PasswordStrength { score, feedback }
}

/// Secure memory clearing for sensitive data
pub trait SecureClear {
    fn secure_clear(&mut self);
}

impl SecureClear for String {
    fn secure_clear(&mut self) {
        unsafe {
            let bytes = self.as_bytes_mut();
            bytes.zeroize();
        }
        self.clear();
    }
}

impl SecureClear for Vec<u8> {
    fn secure_clear(&mut self) {
        self.zeroize();
        self.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_secure_password() {
        let password = SecurePassword::new("test123".to_string());
        assert_eq!(password.len(), 7);
        assert!(!password.is_empty());
        
        let hash = password.hash();
        assert!(password.verify_hash(&hash));
    }

    #[test]
    fn test_password_strength() {
        let weak = SecurePassword::new("123".to_string());
        let strength = validate_password_strength(&weak);
        assert!(strength.score < 40);

        let strong = SecurePassword::new("MyStr0ng!P@ssw0rd".to_string());
        let strength = validate_password_strength(&strong);
        assert!(strength.score >= 80);
    }

    #[test]
    fn test_random_generation() {
        let bytes1 = generate_random_bytes(32);
        let bytes2 = generate_random_bytes(32);
        assert_ne!(bytes1, bytes2);
        assert_eq!(bytes1.len(), 32);
    }
}