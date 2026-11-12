# Forever-free VPS for a backup Nebula lighthouse and relay

Researched **2026-11-12**. Recommendation: **Oracle Cloud Infrastructure (OCI), VM.Standard.A1.Flex, Frankfurt home region, initially 1 OCPU / 6 GB RAM / 50 GB boot disk, with a reserved public IPv4**. It combines an indefinitely free compute allowance, European placement, public UDP and 10 TB/month outbound transfer. Its main weakness for this particular workload is documented idle reclamation: a quiet emergency relay is likely to fall below Oracle's activity thresholds. Treat it as a recoverable second path, monitor it from outside the home, and retain Vesta. [O1] [O2] [O3] [O4] [O5]

**Pay As You Go (PAYG) can still produce a zero monthly bill within free allowances. It is not a verified cure for idle reclamation.** Oracle explicitly confirms continued free allowances after upgrading, but I found no official exemption from idle reclamation for an eligible free VM in a paid tenancy. Upgrading provides support/account options and different capacity limits, but enables overage charges and cannot be undone. Do not buy the recommendation on the assumption that PAYG makes the VM permanent. [O1] [O2]

Ranked shortlist, based on the evidence below:

1. **OCI A1 in Frankfurt**: best fit; comfortable installation RAM and regional relay placement. Choose Frankfurt before signup, because the home region cannot subsequently change. [O1] [O3] [O6]
2. **OCI E2.1.Micro in the same home region**: x86 fallback if A1 capacity is unavailable; same transfer allowance, but only 1 GB RAM and fractional CPU entitlement. It shares Oracle's policy and account risks. [O1] [O4]
3. **Google e2-micro in South Carolina**: conditional alternative only. The VM is indefinitely free, but a public IPv4 costs approximately $3.60 per 30-day month. A public-IPv6-only endpoint avoids the address fee but cannot serve IPv4-only access networks; that is a material limitation for a roaming phone/laptop. There is no free European e2-micro region. [G1] [G2]

Here, “forever free” means a published allowance with **no scheduled expiry**, not a promise that an account, VM, price or capacity allocation can never change. No provider was verified to guarantee this exact service permanently at zero cost. These are research conclusions; no account signup, latency measurement, installation, failover test or configuration change was performed. [O1] [O2] [G1]

## Comparison

Resource amounts are current published allowances, generally shared across an account rather than granted separately to each VM. Geographic latency comments are judgments from region locations, not measured RTTs. [O1] [G1]

| Provider / offer | VM resources and duration | Region / CZ relevance | Public networking and transfer | Verdict |
| --- | --- | --- | --- | --- |
| **OCI A1 Always Free** | **1,500 OCPU-hours + 9,000 GB-hours/month**; equivalent to **2 ARM cores / 12 GB total** continuously; 200 GB combined boot/block storage. One A1 OCPU = one vCPU. No expiry. [O1] [O7] | Home region only. Frankfurt is the preferred nearby commercial region; Amsterdam is another European option if offered at signup. Capacity is not guaranteed. [O1] [O2] [O3] | Public IPv4, optional IPv6; UDP security rules supported; **10 TB/month outbound**. [O1] [O4] [O5] [O8] | **First choice**, with idle-reclamation mitigation. |
| **OCI E2.1.Micro Always Free** | Up to **two x86 VMs**, each **1/8 OCPU, burstable, 1 GB RAM**; shared 200 GB storage pool. Official CPU entitlement is fractional, not one dedicated vCPU. No expiry. [O1] | Same home-region restriction; E2 Micro only in one availability domain in multi-domain regions. [O1] | One public IP/VNIC; up to **50 Mbit/s internet**; same 10 TB outbound allowance. [O1] [O4] | **Second choice**; installation and maintenance need more care. |
| **Google e2-micro Free Tier** | Two visible vCPUs, **0.25 vCPU sustained total**, **1 GB RAM**; **30 GB-month pd-standard**; one non-preemptible VM's monthly hours. No scheduled expiry. [G1] [G3] | Only Oregon `us-west1`, Iowa `us-central1`, South Carolina `us-east1`; South Carolina is my geographic preference for CZ among these, pending measurement. [G1] | IPv4 **$0.005/hour**, less one free hour/month. IPv6 allocation free. Ordinary Premium outbound allowance **1 GB/month**; separate Standard-tier allowance discussed below. [G1] [G2] | **Conditional**, not a generally reachable $0 IPv4 solution. |
| **AWS EC2** | New accounts from **2025-07-15**: free plan lasts **six months or until credits run out**; up to $200 credits. Older introductory EC2 benefit was 12 months. [A1] [A2] | Region choice cannot repair the time limit. | Public IPv4 additionally lists **$0.005/hour**. [A3] | **Exclude: trial**, no verified permanently free EC2 VM. |
| **Azure VMs** | 750 hours/month of specified burstable VM offers for **12 months**. [Z1] [Z2] | Time limit disqualifies it. | Other always-free Azure services do not establish a free permanent VM. [Z2] | **Exclude: introductory benefit**. |
| **IBM Cloud** | Lite managed services have no expiry; current VPC promotion is **70% off for 12 months**, not a free VM. Hyper Protect virtual-server trial lists **1 vCPU for 30 days**. [I1] [I2] | Time/product restrictions disqualify it. | No indefinitely free general VM verified. [I1] [I2] | **Exclude**. |
| **Alibaba Cloud ECS** | Current offer: **$90 credits valid three months**. [B1] | Time limit disqualifies it. | Historical ECS trial advertisements are not an indefinite entitlement. [B1] | **Exclude: credits**. |
| **Fly.io** | Current personal-account waiver makes a complete monthly bill **under $5** payable at $0; cheapest always-on 256 MB Machine is $2.19/30 days in US regions. [F1] | Cheapest documented example is Ashburn/Secaucus, not Europe. [F1] | UDP needs dedicated IPv4, **$2/month**; NA/Europe egress **$0.02/GB**. Crossing $5 charges the **entire bill**. [F1] [F2] [F3] | Interesting conditional $0 **application host**, but full NixOS guest installation not established. [F4] |
| **EUserv VS2-free** | **Linux container**, 1 GB RAM, 10 GB HDD; €0/month but **€2.38 setup** and manual monthly renewal. [E1] | European candidate, but other requirements already fail. | One IPv6 /128, **1 TB/month**; IPv4 optional **€1.19/month**. [E1] | **Exclude**: container, renewal burden, nonzero setup; no documented NixOS guest boot. [E1] [E2] |
| **Scaleway STARDUST1-S** | 1 vCPU / 1 GB, **€0.0006/hour**, before storage. [S1] | Could offer useful European placement, but not free. | IPv4 separate; **€0.005/hour from 2026-06-01**. [S1] [S2] | **Exclude: paid**. |
| **Atlantic.Net** | Advertises a VM free for **one year**. [T1] | Time limit disqualifies it. | No permanent entitlement in that offer. [T1] | **Exclude: trial**. |

## Provider details

### Oracle Cloud: viable, with a real availability caveat

**Allowance freshness matters.** The detailed Always Free documentation, updated **2026-06-12**, and Free Tier overview, updated **2026-06-29**, now specify **2 OCPUs / 12 GB total**, not the familiar historical 4/24 allocation. The current free-tier landing page agrees. Separately, the price list, metadata updated **2026-08-25**, explicitly says **paid tenancies** receive the first **3,000 OCPU-hours / 18,000 GB-hours** free, shared across relevant A1 compute products. The detailed free-resource page still says “all tenancies” for the smaller allowance, so there is a documentation inconsistency in scope. Use **1 core / 6 GB** initially: it is comfortably below either published limit. Verify the actual tenancy allowance before allocating more. [O1] [O9] [O10] [O4]

For A1, one OCPU is one ARM core/vCPU; x86 OCPU-to-vCPU accounting differs. A1 network capacity scales at up to **1 Gbit/s per OCPU**. For E2 Micro, use Oracle's actual specification, **1/8 OCPU with bursting**, rather than mistaking its label for a full dedicated CPU. Its 50 Mbit/s internet ceiling exceeds the supplied 1–5 Mbit/s video assumption, but that is not a measured encrypted relay throughput guarantee. [O1] [O7]

**Disk:** 200 GB total covers boot and attached block volumes together, with five volume backups. The documentation inconsistently mentions both 47 GB and 50 GB minimum/default boot volumes; select **50 GB** and the free-eligible volume settings shown by the console. That is a practical starting budget for a minimal NixOS host with a small number of retained generations; actual closure size and updates must be measured. Do not assume extra capacity/performance options or unlimited retained images/backups are free. [O1] [O4]

**Regions:** free compute and free block volumes must be in the tenancy's **home region**. Free Tier is generally available in commercial regions, but Oracle says the exact signup choices and capacity can differ; government regions are excluded. Frankfurt and Amsterdam are live commercial regions. Frankfurt is my first choice because of its proximity to Czechia; neither provider geography nor a marketing map establishes actual PODA/mobile/foreign-network latency. Choose the home region during signup; Oracle says it **cannot be changed after provisioning**. Upgrading does not remove the documented home-region restriction on Always Free resources. [O1] [O2] [O3] [O6] [O9]

**IPv4/IPv6:** use one **reserved public IPv4** so it can be reassigned to a replacement VM without updating every bootstrap configuration. Oracle's official reserved-IP announcement says there is no charge for the feature; current IP documentation confirms regional reassignment and persistence until explicit deletion. An ephemeral address survives stopping its VM, but is deleted with its underlying VNIC/private IP/instance and cannot simply be converted into a reserved address. The direct no-charge statement is an older source (**2018-01-26**); recheck the current console estimate rather than interpreting old documentation as an immutable price promise. [O5] [O11]

IPv6 is supported across commercial regions: enable a VCN IPv6 prefix, a public IPv6-enabled subnet, a VNIC IPv6 address, an internet gateway and corresponding IPv6 routes/rules. OCI can allocate a /56 to a VCN and /64 to a subnet. A private subnet does not become publicly reachable merely by having global IPv6 addresses. The VCN itself is Always Free with IPv4/IPv6 support. [O1] [O8]

**UDP and firewalls:** OCI security lists and NSGs accept protocol/port rules. For this deployment, create a public subnet and internet gateway; route `0.0.0.0/0` and, if used, `::/0` to it. Add stateful ingress UDP destination **4242**, source ports any, from `0.0.0.0/0` and optionally `::/0`; roaming clients make a home-only source-IP restriction unsuitable. Permit the needed outbound traffic and SSH for administration. Also allow UDP 4242 in the guest firewall if enabled. Default SSH rules alone do not open Nebula. The public IPv4 is mapped to the VNIC's private IPv4, so it need not appear directly on the guest interface. [O5] [O12] [O13]

**Egress:** the first **10 TB/month** of outbound transfer originating in Europe is free; inbound/free-resource details are in Oracle's networking/free-tier documentation. Relay forwarding is outbound traffic on its way to the other peer, even when the video originally arrived from home. Under the user-supplied 1–5 Mbit/s assumption, one hour of mostly one-way video is approximately **0.45–2.25 GB** before encapsulation and return traffic. That calculation makes rare use a comfortable fit for OCI's allowance; it is not a measured JetKVM bitrate. [O1] [O4] [N1]

**Card/account:** Oracle normally requires a phone number and card for identity verification. Its FAQ accepts credit cards and debit cards functioning like credit cards, but excludes PIN debit, virtual, single-use and prepaid cards; temporary authorization holds can occur. Multiple free accounts are prohibited. Do not create another free account to escape an unfortunate region selection. [O2] [O9]

**Idle reclamation is the principal operational risk.** Oracle says it may reclaim an Always Free instance when, over seven days, all applicable conditions hold: CPU 95th-percentile utilization below **20%**, network utilization below **20%**, and memory utilization below **20%** for A1 only. A mostly idle lighthouse/relay is a poor match for these thresholds. Separately, the FAQ says accounts idle for **30 days or more** may be considered abandoned and suspended or terminated. These are different policies; signing into the console is not a documented exemption from compute reclamation. [O1] [O2]

**What PAYG does and does not establish:** Oracle confirms zero charge for eligible resources within free limits after upgrading, no minimum/prepayment, different capacity limits and access to support options. The account cannot subsequently downgrade. The documentation does **not** explicitly say that upgrading prevents reclamation of an otherwise eligible idle free VM. The FAQ sentence “Always Free will not be reclaimed” occurs in its **trial-expiry** discussion; it should not override the explicit idle-reclamation policy. [O1] [O2] [O9]

Recommended mitigation: keep the entire small host configuration reproducible, retain the reserved IP, monitor actual Nebula reachability from outside the home, monitor provider email/account state, and practise replacement/reassignment while the home is healthy. PAYG is reasonable if accepting overage liability for account/support benefits, but ask Oracle for a written answer about idle exemption before relying on it. Use quotas and billing monitoring; do not generate artificial CPU/network load as the reliability plan. Oracle itself documents “out of host capacity” failures and advises another availability domain or retrying later, so even reprovisioning is not guaranteed immediately. [O1] [O2] [O5]

**Termination reports:** the official FAQ provides primary evidence of suspension/termination powers, abandonment policy, lack of Free Tier SLA, and the limited support available to free-only accounts. I did not find an official incident dataset establishing a rate of arbitrary terminations or a blanket PAYG protection. Anecdotal forum stories are not used as quantified evidence here. [O2]

### Google Cloud: indefinite compute, but public IPv4 is paid

The Free Tier documentation, updated **2026-11-10**, grants one non-preemptible e2-micro's worth of monthly hours across **us-west1 / us-central1 / us-east1**, 30 GB-month **standard persistent disk**, and **1 GB outbound/month from North America**, excluding destinations in **China and Australia**. Czech destinations qualify. Select `pd-standard`; the allowance does not make a default balanced/SSD disk free. This is a recurring allowance separate from the **$300 / 90-day** introductory trial. [G1]

The guest exposes **two vCPUs**, but sustains **0.25 vCPU total**, with **1 GB RAM** and short bursts. This is x86_64, not ARM. For this workload I would choose South Carolina before Iowa/Oregon on geography alone; actual routes from Czechia and foreign roaming networks remain unmeasured. No European region qualifies for the free VM. [G1] [G3]

**Address charges are decisive:** standard-VM external IPv4, static or ephemeral, costs **$0.005/hour**. There is **one free hour/month/account**, not one free address all month. A 30-day month therefore costs `(720 − 1) × $0.005 = $3.595` for the address alone, before tax/conversion. A static address attached to a stopped VM is still treated as in use. Reserving a static address solves endpoint stability, not cost. External IPv6 address ranges and VM IPv6 allocation are free, but bandwidth is separate. [G2]

For public IPv6, configure an eligible custom subnet/interface and its IPv6 routes; VPC firewalls support UDP and separate IPv4/IPv6 source ranges. Explicitly permit UDP 4242 and configure the NixOS interface/firewall as needed. Google documents literal IPv6-only instances as supported with **Ubuntu and Debian images**; a NixOS host with internal IPv4 plus external IPv6 on a dual-stack interface is a more plausible route to investigate, not a deployment verified here. Public IPv6 alone still fails for an IPv4-only remote client. [G4] [G5]

**Relay transfer nuance:** the ordinary Premium-tier 1 GB allowance buys approximately **27 minutes at 5 Mbit/s** or **133 minutes at 1 Mbit/s**, before tunnel/control traffic, using decimal GB and the supplied bitrate. However, Google's current pricing page separately grants **200 GiB/month of Standard-tier outbound transfer per account across all regions** and says Always Free limits do not apply to Standard Tier. Premium is the default. The Network Tiers overview inconsistently calls this 200 GB per region/SKU and lists Standard-tier external IPv6 as **Preview**. Consequently, “Google only ever offers 1 GB” is too broad, but a production-ready **$0 IPv6 + 200 GiB** design is not verified. Even confirmed Standard-tier transfer would not eliminate IPv4 address charges. [G1] [G2] [G6]

**Billing/card/longevity:** an active billing account in good standing is required. Trial signup requires a credit card or another supported payment method; country-specific verification can apply. Activate paid billing to keep resources after trial credits/time expire; eligible free usage continues, overages become chargeable. Without upgrading, the trial ends and resources stop, with a recovery grace period followed by deletion. Free Tier has no scheduled end date, but Google reserves changes/removal with **30 days' notice**. No Oracle-style idle-VM utilization reclamation policy was found in the examined Google documentation; that finding is not a permanence guarantee or an account-termination risk estimate. [G1]

### AWS, Azure, IBM and Alibaba: exclude their VM trials

- **AWS:** the EC2 documentation explicitly separates accounts created before **2025-07-15** from newer accounts. New-account free plans last at most six months or until credits are consumed. The announcement dated **2025-07-16** describes up to $200 credits; the older EC2 offer lasted 12 months, so those old introductory periods have already elapsed by this note's date. Some other AWS services can remain always free, but that does not supply a permanent EC2 VM. IPv4 has its own $0.005/hour charge. [A1] [A2] [A3]
- **Azure:** the current VM pricing page advertises 750 monthly hours of specified B2ts v2 / B2pts v2 / B2ats v2 offers for **12 months**. Its free-service catalog explicitly distinguishes first-12-month services from always-free services. No indefinite free general VM was verified. [Z1] [Z2]
- **IBM:** the live free-tier page says Lite offerings never expire, but its current VPC/virtual-server promotion is **70% off for 12 months**, advertised through **2026-12-31**. The Hyper Protect virtual-server trial on its ecosystem page is **30 days**, not a permanent VPS. [I1] [I2]
- **Alibaba:** the current ECS free offer is **$90 credits valid for three months**. That supersedes using historical trial blog posts as evidence of current signup benefits, and neither version is forever free. [B1]

### Smaller providers and application platforms

**Fly.io deserves a qualified mention.** Current official documentation says a personal organization on PAYG with a card has its complete bill waived when it is **strictly below $5**; no end date is stated. At the documented cheapest $2.19/30-day machine plus $2 dedicated IPv4, there is about $0.81 left before the threshold, roughly 40 GB at $0.02/GB before any other costs. UDP requires dedicated IPv4. Machines boot container images, however; a normal full NixOS guest installation, system switching and Nebula/TUN operation were not established. It is not a verified substitute for the requested NixOS VPS, and a threshold waiver is not a spending cap. [F1] [F2] [F3] [F4]

**EUserv VS2-free** advertises a renewable IPv6 Linux container with 1 GB RAM, 10 GB disk and 1 TB/month. Its setup fee, manual monthly renewal and paid IPv4 already make it a poor emergency-access host under this requirement. The published OS list does not document NixOS; a root container is not evidence that kexec, custom kernels or a normal NixOS guest boot are available. [E1] [E2]

**Scaleway** is inexpensive rather than free; STARDUST1-S compute is €0.0006/hour with storage and IPv4 separate. **Atlantic.Net** explicitly offers only a year. **x10VPS** currently lists paid VPS plans, while **GigaRocket** no longer establishes a current free VPS offer on its homepage. [S1] [S2] [T1] [T2] [T3]

**Koyeb and Render** provide free web/container services, not the required public-UDP NixOS VM: Koyeb documents scale-to-zero after an hour and HTTP/HTTP2 public service exposure; Render sleeps free services after 15 minutes and exposes a public HTTP port. **Hax/Woiden** advertise renewable IPv6/NAT hosting, but I could not verify a full VM with supported custom NixOS installation and appropriate public UDP from their official material. They remain unverified, not viable recommendations. [P1] [P2] [P3] [P4] [P5] [P6]

## NixOS installation and maintenance

### Feasibility and installation choices

The NixOS source tree includes OCI guest and QCOW2 image modules, and Google Compute guest/image modules. These establish an upstream NixOS integration path, not provider certification: Oracle's supported Linux import table does **not** list NixOS. A successful boot, networking, switch and reboot on the chosen cloud shape still require validation. [X1] [X2] [X3] [X4] [O14]

**RAM:** the current nixos-anywhere/nixos-images documented kexec floor is **1 GB physical RAM, excluding swap**. Thus 1 GB does not automatically rule out kexec-based installation, but e2-micro/E2 Micro sit exactly at the advertised minimum; usable RAM, installer contents and memory peaks matter. No actual 1 GB cloud install was run for this research. `--no-disko-deps` is documented for low-RAM cases only when required tools already exist in the installer. A1 at 6 GB avoids this particular marginal case. Swap can help an installed system or nixos-infect, but does not replace the documented physical-RAM requirement for the kexec path. [X5] [X6] [X7]

**Architecture:** current nixos-anywhere source automatically selects stock kexec images for **both x86_64 and aarch64**. Its older README/quickstart language saying ARM requires a custom image lags behind the implementation. This note uses the source at **4270e9aae9790d18188d667b40b05cfd9746141a**, rather than inferring lack of ARM support from that README. The source selects a `nixos-25.11` installer image; that need not dictate the installed system's nixpkgs revision. [X7] [X8]

**Remote building:** current flags support `--build-on local|remote|auto`. Prefer explicit `local`, with a capable initiating host/builder for the target architecture: Ceres for x86, or Juno/native ARM or a configured aarch64 remote builder for A1. Automatic architecture fallback can otherwise build on the tiny target. A 1 GB host may run a small downloaded closure, but local evaluation/building and peak activation RAM are separate questions. Build elsewhere, copy closures and activate remotely, retain few generations, and measure disk/RAM headroom during the first real upgrade. This follows the repository's existing build-on-another-host approach without claiming that its current `update --vesta` command already supports a new VPS. [X7] [X9] [R1]

**nixos-infect fallback:** its own README records successful OCI E2 Micro/A1 infections, including ARM Ubuntu 22.04 (**2022-11-13**) and Oracle Linux 8.10 (**2024-06-03**). Its GCP table records Debian 11 success and Ubuntu 20.04 failure (**2023-11-12**, with an apparent “ec2-micro” typo). These are historical reports, not current certification. The script creates 1 GiB temporary swap by default and converts the installed filesystem instead of requiring a RAM-only kexec installer. Review and pin it, retain recovery access, and use it as a fallback when kexec is blocked or marginal. [X10] [X11]

**Custom-image fallback:** NixOS's OCI module builds `system.build.OCIImage` as QCOW2, with an 8 GiB default image size, metadata-v2 SSH-key retrieval and OCI guest support. Google has a native compressed `disk.raw` image output. Image upload/import avoids target installation-RAM pressure but adds storage/import accounting and platform boot compatibility work. Oracle's generic Linux import guide requires paravirtualized mode on ARM yet also gives BIOS/MBR guidance that conflicts with an ARM/UEFI image route; verify the ARM-specific capabilities instead of copying those generic settings. Custom-image launch eligibility on a free-only OCI account must also be checked: the free-resource docs restrict non-free-eligible images to trial/paid accounts. [X1] [X2] [X3] [X4] [O1] [O14]

### Concrete proposed route: OCI A1, 1 core / 6 GB

These are **future execution steps**, not changes made by this research. Disk replacement is intentional only on the newly created VPS. Command placeholders need the future host configuration, account and verified addresses. [X7] [X9]

1. **Choose the account/home region first.** Select **Germany Central (Frankfurt)** if offered, before completing signup. Decide whether to remain free-only or accept PAYG liability for support/account benefits; keep the initial resources below the smaller published free allocation. Confirm the console estimate and free-eligible shape/storage before launch. Home-region choice is permanent; A1 capacity is not assured. [O1] [O2] [O3] [O6]

2. **Create the cloud network and instance.** Use an A1-compatible Ubuntu platform image, 1 OCPU, 6 GB, a 50 GB free-eligible boot volume, public subnet and internet gateway. Assign a **reserved IPv4** to its VNIC; optionally configure global IPv6. Add the UDP 4242 cloud rules above and administrative SSH. Keep OCI console/recovery access available before replacing Ubuntu. [O1] [O5] [O8] [O12]

3. **Inspect the actual machine before defining disks/boot.** Check architecture, memory, block-device identity, firmware, DHCP and SSH/sudo access. For example, over SSH run `uname -m`, `free -h`, `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS` and `test -d /sys/firmware/efi`. Prepare a future `systems/aarch64-linux/<vps-host>/` Snowfall host with Disko for the observed disk and EFI boot, DHCP/virtio support, SSH, Nix, sops-nix and Nebula. Do not copy Juno's DGX kernel/hardware or the full server service role. OCI guest module defaults for root/ESP labels must agree with the chosen Disko layout. [X1] [X2] [X9] [R1] [R2]

4. **Build on a healthy ARM machine or configured ARM builder.** Make the future configuration available on Juno (or initiate from Ceres with a functioning aarch64 builder). Inspect/pin nixos-anywhere and use its current aarch64 support. First build the future host's toplevel and perform the installer's documented VM test when the host configuration permits it. Then the command template, run from the native ARM initiating host, is: [X7] [X8] [X9]

   ```sh
   nix run github:nix-community/nixos-anywhere/4270e9aae9790d18188d667b40b05cfd9746141a -- \
     --flake '.#<vps-host>' \
     --build-on local \
     --target-host 'ubuntu@<reserved-public-ipv4>'
   ```

   The initial user must have passwordless sudo, or use a directly authorized root login. The installer uses SSH, kexec, Disko and a remotely copied system closure. If kexec is blocked, stop and use a reviewed nixos-infect conversion or verified OCI image route; do not assume a failed kexec implies the A1 architecture is unsupported. [X7] [X9] [X10]

5. **Provision secrets and verify persistence.** Give the host its own Nebula leaf certificate/key and SOPS recipient, using the repository's existing signing/secret process. Keep the CA signing private key off the VPS. Ensure the SSH host identity used for SOPS is deliberately preserved/provisioned through installation so secrets decrypt on first boot. Verify SSH, IPv4/IPv6, clock, Nebula and a full switch/reboot; then exercise another closure transfer and activation from the selected builder. This is a proposed acceptance gate, not a measured guarantee that a particular closure fits. [R1] [R2] [R3] [X12]

6. **Update every relevant peer before depending on failover.** The repository currently points its lighthouse/relay lists and static map at Vesta; the mobile renderer also hardcodes Vesta and sends phone DNS to Vesta. Add both lighthouses' bootstrap endpoints and advertise both eligible relays on the laptop, phone and KVM peers. Set the VPS to lighthouse **and** relay, and do not configure it to relay via Vesta: Nebula does not relay to a relay. Its relay list is what a peer advertises as paths **to itself**, so adding a relay only on the laptop is insufficient. Keep bootstrap addresses numeric or independently resolvable. Use KVM overlay IPs or DNS that remains available when Vesta is off. These are implementation requirements derived from the inspected configuration and upstream semantics, not configuration changes in this note. [R2] [R4] [N1] [N2] [N3]

7. **Prove the actual recovery scenario.** From a foreign/mobile network, start with no cached tunnels and Vesta unavailable; reach each independently powered KVM, view video and operate its ATX control. Also test a deliberately forced relay path, then measure latency, throughput and billed egress. Verify recovery after restarting the phone/laptop/KVM, since an already-established direct tunnel does not prove lighthouse failover. Configure off-home monitoring and practise reserved-IP reassignment/reprovisioning. The VPS only removes the Vesta-host dependency; the home router, ISP and KVM power/network must still work. [N1] [N2] [N3] [O5]

## Open questions and unknowns

- **PAYG idle exemption:** no official guarantee located. Obtain a written Oracle answer about an Always Free-eligible idle A1 in a paid tenancy. Free usage continuing after upgrade is verified; non-reclamation is not. [O1] [O2]
- **Actual signup/capacity/allowances:** Frankfurt availability for this new Czech account, A1 stock, the exact paid/free allowance distinction and custom-image eligibility must be confirmed in the account. Public pages cannot reserve capacity. [O1] [O2] [O4]
- **Real latency and video behavior:** no PODA/Czech-mobile/abroad measurements or JetKVM relay benchmarks were performed. Region proximity is the basis of the ranking, and 1–5 Mbit/s was supplied by the task rather than independently measured.
- **JetKVM integration:** native Nebula installation, TUN support, persistent startup and firmware-upgrade behavior on the two actual devices were not verified from primary documentation. Each needs its own working peer, or an independently powered LAN gateway that survives both managed hosts being off. A VPS cannot compensate for Nebula running only on Vesta/Ceres or for loss of the home router/ISP/power.
- **NixOS acceptance:** no actual A1/E2/e2-micro install, switch or reboot was run. Current source supports ARM kexec; exact 1 GB memory success and the OCI image's ARM firmware/import settings remain to be validated. [X5] [X7] [O14]
- **Google Standard-tier IPv6:** verify Preview eligibility, routing and actual billing before relying on the 200 GiB allowance with a no-public-IPv4 NixOS design. Pricing/overview units and scope differ. [G2] [G6]
- **Termination frequency:** official policies are documented, but no primary dataset was located for arbitrary OCI/Google account-termination rates. No claim that a paid upgrade eliminates account risk is supported here. [O2] [G1]
- **DNS during outage:** the current phone configuration's Vesta DNS dependency requires an intentional solution or direct overlay-IP access. A second lighthouse does not itself provide a replacement recursive resolver. [R4] [N2]

## Sources and date handling

**All external sources below were accessed on 2026-11-12.** Undated pages use that access date; it does not establish their publication date. Oracle detailed pages exposed update dates noted above; its free-tier marketing FAQ/landing metadata still says 2024-09-10 despite current content, so that metadata is not treated as proof of offer age. Google pages cited by the researcher exposed 2026-11-10 updates. AWS's announcement is explicitly dated 2025-07-16; Oracle's reserved-IP announcement is explicitly dated 2018-01-26. NixOS/nixos-anywhere source is primary project evidence, not provider certification. Repository context was read locally at commit `4ccfc6fdd6cd6c471d168cc3aff1e924579c2f12`; links below identify those same files.

[O1]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm "OCI Always Free Resources; updated 2026-06-12; accessed 2026-11-12"
[O2]: https://www.oracle.com/cloud/free/faq/ "OCI Free Tier FAQ; accessed 2026-11-12"
[O3]: https://www.oracle.com/cloud/public-cloud-regions/ "OCI public regions; metadata updated 2026-11-04; accessed 2026-11-12"
[O4]: https://www.oracle.com/cloud/price-list/ "OCI price list; metadata updated 2026-08-25; accessed 2026-11-12"
[O5]: https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingpublicIPs.htm "OCI public IP addresses; updated 2026-02-03; accessed 2026-11-12"
[O6]: https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingregions.htm "OCI home region; updated 2025-01-14; accessed 2026-11-12"
[O7]: https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm "OCI compute shapes; updated 2026-08-14; accessed 2026-11-12"
[O8]: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/ipv6.htm "OCI IPv6; updated 2026-07-07; accessed 2026-11-12"
[O9]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm "OCI Free Tier overview; updated 2026-06-29; accessed 2026-11-12"
[O10]: https://www.oracle.com/cloud/free/ "OCI Free Tier landing page; accessed 2026-11-12"
[O11]: https://blogs.oracle.com/cloud-infrastructure/release-announcement-reserved-public-ips-are-now-available-on-oracle-cloud-infrastructure "Oracle reserved public IP announcement; published 2018-01-26; accessed 2026-11-12"
[O12]: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securityrules.htm "OCI security rules; updated 2026-01-14; accessed 2026-11-12"
[O13]: https://www.oracle.com/cloud/networking/virtual-cloud-network/faq/ "OCI VCN FAQ; accessed 2026-11-12"
[O14]: https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/importingcustomimagelinux.htm "OCI custom Linux import; updated 2026-09-16; accessed 2026-11-12"
[G1]: https://cloud.google.com/free/docs/free-cloud-features#compute "Google Free Tier; updated 2026-11-10; accessed 2026-11-12"
[G2]: https://cloud.google.com/vpc/network-pricing "Google VPC network pricing, including IP and Standard Tier; accessed 2026-11-12"
[G3]: https://cloud.google.com/compute/docs/general-purpose-machines#e2_shared-core "Google E2 shared-core specifications; updated 2026-11-10; accessed 2026-11-12"
[G4]: https://cloud.google.com/compute/docs/ip-addresses/configure-ipv6-address "Google IPv6 configuration; updated 2026-11-10; accessed 2026-11-12"
[G5]: https://cloud.google.com/firewall/docs/firewalls "Google VPC firewalls; updated 2026-11-10; accessed 2026-11-12"
[G6]: https://cloud.google.com/network-tiers/docs/overview "Google Network Tiers overview; updated 2026-11-10; accessed 2026-11-12"
[A1]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html "AWS EC2 Free Tier; accessed 2026-11-12"
[A2]: https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan/ "AWS new Free Tier announcement; published 2025-07-16; accessed 2026-11-12"
[A3]: https://aws.amazon.com/vpc/pricing/ "AWS VPC pricing; accessed 2026-11-12"
[Z1]: https://azure.microsoft.com/en-us/pricing/details/virtual-machines/windows/ "Azure VM introductory offer; accessed 2026-11-12"
[Z2]: https://azure.microsoft.com/en-us/pricing/free-services "Azure free service categories; accessed 2026-11-12"
[I1]: https://www.ibm.com/products/cloud/free "IBM Cloud free and promotional offers; accessed 2026-11-12"
[I2]: https://www.ibm.com/products/cloud/free/kubernetes "IBM free ecosystem offers; accessed 2026-11-12"
[B1]: https://www.alibabacloud.com/en/free?_p_lc=1 "Alibaba current free offers; accessed 2026-11-12"
[F1]: https://docs.fly.io/about/free-waiver "Fly personal account bill waiver; accessed 2026-11-12"
[F2]: https://docs.fly.io/networking/udp-and-tcp "Fly UDP networking; accessed 2026-11-12"
[F3]: https://docs.fly.io/about/pricing "Fly resource pricing; accessed 2026-11-12"
[F4]: https://docs.fly.io/machines/overview "Fly Machines and container images; accessed 2026-11-12"
[E1]: https://www.euserv.com/en/virtual-private-server/root-vserver/v2/vs2-free.php "EUserv VS2-free product and fees; accessed 2026-11-12"
[E2]: https://www.euserv.com/en/virtual-private-server/features/operating-systems-v2.php "EUserv container OS choices; accessed 2026-11-12"
[S1]: https://www.scaleway.com/en/pricing/virtual-instances/ "Scaleway instance pricing; accessed 2026-11-12"
[S2]: https://www.scaleway.com/en/blog/a-transparent-update-on-scaleway-pricing/ "Scaleway pricing change effective 2026-06-01; accessed 2026-11-12"
[T1]: https://www.atlantic.net/announcements/atlantic-net-offers-one-year-of-free-cloud-hosting/ "Atlantic.Net one-year offer; accessed 2026-11-12"
[T2]: https://x10vps.com/plans "x10VPS current plans; accessed 2026-11-12"
[T3]: https://www.gigarocket.net/ "GigaRocket current homepage; accessed 2026-11-12"
[P1]: https://www.koyeb.com/docs/reference/instances "Koyeb free instance limits; accessed 2026-11-12"
[P2]: https://www.koyeb.com/docs/build-and-deploy/exposing-your-service "Koyeb public protocols; accessed 2026-11-12"
[P3]: https://render.com/docs/free "Render free service limits; accessed 2026-11-12"
[P4]: https://render.com/docs/web-services "Render HTTP service networking; accessed 2026-11-12"
[P5]: https://hax.co.id/ "Hax official offer; accessed 2026-11-12"
[P6]: https://woiden.id/ "Woiden official offer; accessed 2026-11-12"
[N1]: https://nebula.defined.net/docs/config/relay/ "Nebula relay semantics; accessed 2026-11-12"
[N2]: https://nebula.defined.net/docs/config/lighthouse/ "Nebula lighthouse semantics; accessed 2026-11-12"
[N3]: https://nebula.defined.net/docs/config/static-host-map/ "Nebula bootstrap mappings; accessed 2026-11-12"
[X1]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/oci-common.nix "NixOS OCI guest configuration; accessed 2026-11-12"
[X2]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/oci-image.nix "NixOS OCI QCOW2 builder; accessed 2026-11-12"
[X3]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/google-compute-image.nix "NixOS GCP image builder; accessed 2026-11-12"
[X4]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/google-compute-config.nix "NixOS GCP guest configuration; accessed 2026-11-12"
[X5]: https://github.com/nix-community/nixos-anywhere/blob/6dd77413f8cedb7c6b4c4f5633a86d504ba78c5c/README.md#prerequisites "nixos-anywhere prerequisite documentation; README last changed 2025-07-09; accessed 2026-11-12"
[X6]: https://github.com/nix-community/nixos-images#requirements "nixos-images kexec RAM prerequisites; accessed 2026-11-12"
[X7]: https://github.com/nix-community/nixos-anywhere/blob/4270e9aae9790d18188d667b40b05cfd9746141a/src/nixos-anywhere.sh "nixos-anywhere implementation and flags; script last changed 2026-05-26; accessed 2026-11-12"
[X8]: https://github.com/nix-community/nixos-anywhere/blob/9c3de7d78d461cd31c86db196ae8b7746c081978/docs/howtos/custom-kexec.md "nixos-anywhere custom kexec documentation; accessed 2026-11-12"
[X9]: https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md "nixos-anywhere installation, disk and SSH prerequisites; accessed 2026-11-12"
[X10]: https://github.com/elitak/nixos-infect "nixos-infect provider test reports; accessed 2026-11-12"
[X11]: https://github.com/elitak/nixos-infect/blob/master/nixos-infect "nixos-infect implementation and swap creation; accessed 2026-11-12"
[X12]: https://github.com/Mic92/sops-nix "sops-nix host keys and secret provisioning; accessed 2026-11-12"
[R1]: https://github.com/sgiath/nixos-config/blob/4ccfc6fdd6cd6c471d168cc3aff1e924579c2f12/AGENTS.md "Repository instructions, Snowfall layout and remote build workflow; inspected locally 2026-11-12"
[R2]: https://github.com/sgiath/nixos-config/blob/4ccfc6fdd6cd6c471d168cc3aff1e924579c2f12/modules/nixos/common/nebula.nix "Repository shared Nebula configuration; inspected locally 2026-11-12"
[R3]: https://github.com/sgiath/nixos-config/blob/4ccfc6fdd6cd6c471d168cc3aff1e924579c2f12/systems/x86_64-linux/vesta/default.nix "Repository current lighthouse/relay; inspected locally 2026-11-12"
[R4]: https://github.com/sgiath/nixos-config/blob/4ccfc6fdd6cd6c471d168cc3aff1e924579c2f12/scripts/nebula-mobile.sh "Repository mobile bootstrap, relay and DNS rendering; inspected locally 2026-11-12"
