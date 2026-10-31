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

## Briefing someone outside the topic

Use this shape when the reader has to act on, or pass on, something they don't
know well: a teammate asked to take a question to another team, or a decision
that needs someone else's confirmation. Give them a rough overview they can
forward without rewriting, not a deep dive.

1. Mention them and say the problem in one sentence, including where it bites.
   End the paragraph with the ask in bold.
2. **What the rule says**: one or two plain sentences for a non-specialist, then
   a short list of references. Give each primary source as a link, quote its
   key line in the original language, and add the internal summary if there is
   one.
3. **The difference**: side by side, with the real numbers for each affected
   case. Say what each side does, what changes as a result, and what does not
   change.
4. What has already been decided, if anything, and what it means for others.
5. **What we need**: bullets that cover each outcome, such as "if they agree,
   X needs correcting" and "if they have a reason, send the source so we can
   Y".
6. The ticket that tracks it.

Synthetic; reuse the structure, not the facts:

> @Maria our reference invoices and the accounting research disagree on when a
> yearly maintenance fee counts as revenue, and it changes two of the reference
> invoices. **Could you pass this to Finance and ask them which one is right?**
>
> **What the rule says, per the research:** a fee for a service delivered over a
> year is recognised a twelfth at a time, as the service is delivered, not in
> the month it is invoiced.
> - Standard, section 7: "revenue is recognised as the obligation is satisfied
>   over time" https://example.org/standard#7
> - The research summary: https://example.org/research/maintenance-fees
>
> **The difference on the reference invoices:**
> - The invoices book the whole fee in the month it is billed: 12,000.00 on
>   invoice 1, 9,600.00 on invoice 3.
> - The rule books a twelfth every month: 1,000.00 and 800.00.
> - March revenue on invoice 1 goes from 12,000.00 to 1,000.00. Totals for the
>   year don't change.
>
> We now follow the research (ACME-412). That means the billing service has to
> send the contract term with each fee.
>
> What we need from Finance:
> - whether they agree. If so, invoices 1 and 3 need correcting;
> - if they book it when billed for a reason, the source for that, so we can
>   give it to the research team.

## Final check

Confirm that the text answers the actual point, preserves its facts and
uncertainty, makes no commitment he did not make, and contains nothing added to
sound casual or human.
