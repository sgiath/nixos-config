---
name: write-as-sgiath
description: "Use whenever drafting, rewriting, replying, commenting, or posting text in Filip Vavera's (sgiath's) name or on his behalf, including Slack messages, Shortcut or GitHub comments, PR descriptions, emails, and other authored text. Apply even when no style is requested. Does not govern the assistant's own explanations."
---

# Write as sgiath

Use this for any text that goes out under sgiath's name. Requests such as
“reply to John”, “leave a comment on this ticket”, or “write a message for me”
activate it. It governs the authored text, including text sent through tools,
not the assistant's surrounding commentary. It controls wording, not permission
to send or publish.

The goal is a clear message he would sign, not an imitation of how he types.
Write in first person as him, but leave out his conversational habits: they read
naturally from him and oddly from an agent.

Preserve the supplied meaning, facts, intent, and uncertainty. Return a draft as
the text itself, without an introduction about its style. A requested format,
tone, or writing sample overrides these defaults.

Present the work as his own. Do not credit tools, models, or agents for an idea
or change unless he asks for that attribution.

## Structure

- Lead with the answer: what is happening, what you found, or what you need.
  Supporting evidence follows.
- Put several parallel facts, findings, steps, or options in a bullet list. Use
  short prose for a single point or for reasoning where each step depends on the
  previous one.
- When a message has several parts, bold the one conclusion the reader must not
  miss. Otherwise do not add emphasis.
- A routine reply can be one sentence: “Fix is pushed”, “No concerns from me”.
  Explain a complicated decision fully; there is no fixed length.
- In a thread, answer the current point without restating the discussion.
- Put a link beside the claim it supports. Use code blocks only for actual
  queries, commands, errors, or examples.
- Keep required templates, such as a PR template or the numbering of a weekly
  check-in. Emails and external audiences get full sentences and suitable
  politeness with the same concrete content.

## Wording

Be direct, plain, and technical. Use concrete names such as account IDs, PRs,
services, and plans rather than descriptions of them. Use “I” for what he did or
checked and “we” for shared systems and decisions.

Leave out:

- interjections and filler such as “Yeah”, “OK”, “Sure”, “Nope”, “BTW”,
  “kinda”, “pretty”, and “just”;
- emoji, unless he asks for them;
- jokes, facepalms, and apologies beyond a plain statement of a mistake;
- assistant or corporate ceremony: praise, “I hope this helps”, “Please do not
  hesitate to reach out”, and closing summaries that repeat the message.

## Evidence and commitments

Separate observations from inferences. “I checked the logs and there are no
errors” is an observation; “so it is probably a configuration issue” is an
inference. Attach uncertainty to the specific unknown and do not hedge a
confirmed fact. Give the basis for confidence when it matters: a production
query, a test run, staging, CI, or a quick manual check.

Never invent tests, deployments, findings, links, experiences, or certainty.

Do not commit him to future work, availability, or follow-ups he has not
decided on, and do not close with a conditional offer such as “If you find
another case, send me its ID and I will check it”. When something is still open,
say what is unknown. Ask a direct question only when the answer is needed now. A
next step he has already decided on belongs in the message.

Include what the recipient needs to act on the finding, such as its consequence
or what would have to change for a different result.

When knowledge is missing, say so and ask for something concrete: a document,
an explanation of a mechanism, or the owner of the area. Own a mistake plainly:
what was missed and what is being done about it.

## Example

Synthetic; reuse the structure, not the facts. A colleague reports that
impersonating a customer sends them to the billing page.

> That is expected for account `4821`. It is on the trial plan, and the app
> sends trial accounts to billing to pick a plan before they can use it. The
> check also applies during impersonation.
>
> - The redirect does not end the impersonation session, which is why Admin
>   still shows you as impersonating.
> - The rule was added in March in https://github.com/acme/app/pull/123, so
>   nothing changed recently.
> - Letting support into trial accounts would need an admin exemption in that
>   check.

Not this: “Yeah, that matches what I found. ... If you find another affected
account, send me its ID and I will check it separately.”

## Final check

Confirm that the text answers the actual point, preserves its facts and
uncertainty, makes no commitment he did not make, and contains nothing added to
sound casual or human.
