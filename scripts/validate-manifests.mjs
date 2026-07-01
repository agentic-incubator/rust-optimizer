#!/usr/bin/env node
// Structural validator for the marketplace + plugin manifests.
// Runs on plain Node — no dependencies — so CI can invoke it before installing anything.
//
// It checks that:
//   - .claude-plugin/marketplace.json parses and has the required shape
//   - every listed plugin's source directory exists and contains a plugin.json
//   - each plugin.json parses and has the required shape
//   - the plugin version matches the marketplace metadata.version (release-please keeps these in sync)
//   - the plugin name matches the entry in the marketplace
// A mismatch here is exactly the kind of drift that silently breaks `/plugin install`, so we fail loud.

import { readFileSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const err = (msg) => errors.push(msg);

function readJson(relPath) {
  const abs = join(root, relPath);
  if (!existsSync(abs)) {
    err(`Missing file: ${relPath}`);
    return null;
  }
  try {
    return JSON.parse(readFileSync(abs, "utf8"));
  } catch (e) {
    err(`Invalid JSON in ${relPath}: ${e.message}`);
    return null;
  }
}

const marketplace = readJson(".claude-plugin/marketplace.json");
if (marketplace) {
  if (!marketplace.name) err("marketplace.json: missing `name`");
  if (!marketplace.owner?.name) err("marketplace.json: missing `owner.name`");
  const marketVersion = marketplace.metadata?.version;
  if (!marketVersion) err("marketplace.json: missing `metadata.version`");
  if (!Array.isArray(marketplace.plugins) || marketplace.plugins.length === 0) {
    err("marketplace.json: `plugins` must be a non-empty array");
  }

  for (const entry of marketplace.plugins ?? []) {
    if (!entry.name) err("marketplace.json: a plugin entry is missing `name`");
    if (!entry.source) {
      err(`marketplace.json: plugin "${entry.name}" is missing source`);
      continue;
    }
    if (!entry.description) {
      err(`marketplace.json: plugin "${entry.name}" is missing description`);
    }

    const pluginDir = join(root, entry.source);
    if (!existsSync(pluginDir)) {
      err(`Plugin source directory not found: ${entry.source}`);
      continue;
    }

    const pluginManifestRel = join(entry.source, ".claude-plugin", "plugin.json");
    const plugin = readJson(pluginManifestRel);
    if (!plugin) continue;

    if (!plugin.name) err(`${pluginManifestRel}: missing name`);
    if (plugin.name && entry.name && plugin.name !== entry.name) {
      err(
        `Name mismatch: marketplace lists "${entry.name}" but ${pluginManifestRel} says "${plugin.name}"`,
      );
    }
    if (!plugin.version) err(`${pluginManifestRel}: missing version`);
    if (plugin.version && marketVersion && plugin.version !== marketVersion) {
      err(
        `Version drift: ${pluginManifestRel} is ${plugin.version} but marketplace.json metadata.version is ${marketVersion}`,
      );
    }
    if (!plugin.description) err(`${pluginManifestRel}: missing description`);
    if (!plugin.author?.name) err(`${pluginManifestRel}: missing author.name`);
  }
}

if (errors.length > 0) {
  console.error(`✗ Manifest validation failed (${errors.length} problem(s)):`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}

console.log("✓ Manifests valid.");
