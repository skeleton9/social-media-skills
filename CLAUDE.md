# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Claude Code skills for social media curators. Skills are specialized capabilities that extend Claude Code's functionality for content creation, editing, and publication across various social media platforms.

## Skill Development

### Creating New Skills

Skills in this repository should follow the Claude Code skill format:
- Each skill is defined in a markdown file with YAML frontmatter
- Skills should have clear trigger conditions in their descriptions
- Include examples of when to use the skill vs. when not to use it
- Specify required tools and dependencies in the frontmatter

### Skill Organization

Organize skills by category or platform:
- Content creation (e.g., post generation, image creation, video scripting)
- Content editing and formatting
- Platform-specific utilities (X/Twitter, WeChat, Xiaohongshu, etc.)
- Analytics and reporting tools

### Testing Skills

Before deployment:
1. Test skills in isolation using the Skill tool
2. Verify trigger conditions work as expected
3. Test edge cases and error handling
4. Confirm the skill integrates properly with other related skills

### Dependencies

Skills in this repository may depend on:
- External APIs (social media platforms, AI generation services)
- Local tools and utilities
- Environment variables for authentication
- MCP servers for platform integrations

Document all dependencies clearly in each skill's description and setup instructions.

## Integration with Claude Code

Skills from this repository are loaded into Claude Code's skill system. When a user's request matches a skill's trigger condition, Claude Code should invoke it using the Skill tool rather than attempting to implement the functionality manually.

## Platform-Specific Considerations

### Social Media APIs
- Always check for required authentication tokens
- Respect rate limits and API quotas
- Handle platform-specific content restrictions (character limits, media formats)

### Content Generation
- Maintain consistent tone and style within platform conventions
- Consider target audience and platform culture
- Optimize media formats for each platform's requirements
