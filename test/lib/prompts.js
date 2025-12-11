#!/usr/bin/env node
import readline from 'readline';

/**
 * Create a readline interface
 */
function createInterface() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

/**
 * Prompt for user input
 */
export function prompt(question) {
  const rl = createInterface();
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

/**
 * Prompt for yes/no confirmation
 */
export async function confirm(question, defaultValue = false) {
  const defaultText = defaultValue ? 'Y/n' : 'y/N';
  const answer = await prompt(`${question} [${defaultText}]: `);
  if (!answer) {
    return defaultValue;
  }
  return answer.toLowerCase().startsWith('y');
}

/**
 * Prompt for selection from a list
 */
export async function select(question, options) {
  console.log(`\n${question}`);
  options.forEach((option, index) => {
    if (typeof option === 'string') {
      console.log(`  ${index + 1}. ${option}`);
    } else {
      console.log(`  ${index + 1}. ${option.label || option.value || option}`);
    }
  });
  const answer = await prompt('\nSelect option (number): ');
  const index = parseInt(answer, 10) - 1;
  if (index >= 0 && index < options.length) {
    return typeof options[index] === 'string' ? options[index] : options[index].value || options[index];
  }
  throw new Error('Invalid selection');
}

/**
 * Prompt for multiple selections
 */
export async function multiSelect(question, options) {
  console.log(`\n${question} (select multiple, comma-separated)`);
  options.forEach((option, index) => {
    if (typeof option === 'string') {
      console.log(`  ${index + 1}. ${option}`);
    } else {
      console.log(`  ${index + 1}. ${option.label || option.value || option}`);
    }
  });
  const answer = await prompt('\nSelect options (e.g., 1,3,5): ');
  const indices = answer
    .split(',')
    .map((s) => parseInt(s.trim(), 10) - 1)
    .filter((i) => i >= 0 && i < options.length);
  return indices.map((i) => (typeof options[i] === 'string' ? options[i] : options[i].value || options[i]));
}

/**
 * Display a table
 */
export function displayTable(headers, rows) {
  // Calculate column widths
  const widths = headers.map((header, i) => {
    const headerLen = String(header).length;
    const maxRowLen = Math.max(...rows.map((row) => String(row[i] || '').length));
    return Math.max(headerLen, maxRowLen, 5);
  });

  // Print header
  const headerRow = headers.map((h, i) => String(h).padEnd(widths[i])).join(' | ');
  console.log(headerRow);
  console.log('-'.repeat(headerRow.length));

  // Print rows
  rows.forEach((row) => {
    const rowStr = headers.map((_, i) => String(row[i] || '').padEnd(widths[i])).join(' | ');
    console.log(rowStr);
  });
}

/**
 * Display key-value pairs in a formatted way
 */
export function displayKeyValue(data, title = null) {
  if (title) {
    console.log(`\n${title}`);
    console.log('-'.repeat(title.length));
  }
  Object.entries(data).forEach(([key, value]) => {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      console.log(`\n${key}:`);
      displayKeyValue(value);
    } else {
      console.log(`  ${key}: ${value}`);
    }
  });
}

/**
 * Wait for user to press Enter
 */
export async function waitForEnter(message = 'Press Enter to continue...') {
  await prompt(message);
}

/**
 * Display a separator line
 */
export function separator(char = '=') {
  console.log(char.repeat(60));
}

/**
 * Display a section header
 */
export function sectionHeader(title) {
  separator();
  console.log(`  ${title}`);
  separator();
}
