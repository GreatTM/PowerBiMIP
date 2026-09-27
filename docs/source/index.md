---
hide-toc: true
description: PowerBiMIP is an open-source modeling and solving framework for bilevel mixed-integer programming in power and energy systems.
---

# PowerBiMIP

<div class="pb-home">
  <section class="pb-hero" aria-labelledby="hero-heading">
    <div class="pb-hero-copy">
      <p class="pb-eyebrow"><span class="pb-status-dot" aria-hidden="true"></span> OPEN-SOURCE OPTIMIZATION</p>
      <img class="pb-hero-logo" src="_static/PowerBiMIP_logo.svg" alt="PowerBiMIP" width="704" height="168">
      <h2 id="hero-heading">Bilevel Mixed-Integer<br><span>Programming</span></h2>
      <p class="pb-hero-subtitle">Built for power &amp; energy systems.</p>
      <p class="pb-hero-description">PowerBiMIP is an open-source, efficient bilevel mixed-integer programming (BiMIP) solver, with a special focus on applications in power and energy systems.</p>
      <div class="pb-actions">
        <a class="pb-button pb-button-primary" href="installation.html">Get started <span aria-hidden="true">↗</span></a>
        <a class="pb-button pb-button-secondary" href="https://github.com/GreatTM/PowerBiMIP">View on GitHub <span aria-hidden="true">↗</span></a>
      </div>
      <p class="pb-hero-footnote">MATLAB + YALMIP <span aria-hidden="true">/</span> Academic &amp; non-commercial research</p>
    </div>
    <div class="pb-model" role="img" aria-label="Bilevel optimization: upper-level decisions influence a lower-level optimization problem, whose optimal response feeds back into the upper level.">
      <div class="pb-model-header"><span>THE BILEVEL STRUCTURE</span><span class="pb-model-symbol" aria-hidden="true">↗</span></div>
      <div class="pb-model-level pb-model-upper">
        <div class="pb-level-caption"><span>01 / UPPER LEVEL</span><span class="pb-level-variable">x</span></div>
        <strong>Decide the strategy.</strong>
        <p>Planning · investment · policy</p>
        <div class="pb-equation">min<sub>x</sub> F(x, y)</div>
      </div>
      <div class="pb-model-connectors" aria-hidden="true"><span><b>↓</b> Decisions</span><span>Optimal response <b>↑</b></span></div>
      <div class="pb-model-level pb-model-lower">
        <div class="pb-level-caption"><span>02 / LOWER LEVEL</span><span class="pb-level-variable">y</span></div>
        <strong>Optimize the response.</strong>
        <p>Operation · dispatch · adaptation</p>
        <div class="pb-equation">y ∈ arg min<sub>z</sub> f(x, z)</div>
      </div>
      <div class="pb-model-footer"><span class="pb-status-dot" aria-hidden="true"></span> Continuous &amp; integer variables at both levels</div>
    </div>
  </section>

  <aside class="pb-announcement" aria-label="Python version announcement">
    <span class="pb-announcement-label">COMING NEXT</span>
    <p><strong>Python meets PowerBiMIP.</strong> Pyomo modeling support is in development.</p>
    <a href="https://github.com/GreatTM/PowerBiMIP/releases">Follow releases <span aria-hidden="true">↗</span></a>
  </aside>

  <section class="pb-section" aria-labelledby="start-heading">
    <div class="pb-section-heading"><div><p class="pb-eyebrow">START EXPLORING</p><h2 id="start-heading">From your first model to real systems.</h2></div></div>
    <div class="pb-entry-grid">
      <a class="pb-entry" href="installation.html"><span class="pb-entry-top"><span>01 / SET UP</span><b aria-hidden="true">↗</b></span><h3>Install PowerBiMIP</h3><p>Prepare MATLAB, YALMIP and your MILP solver. Run the installer and a first example.</p><span class="pb-entry-link">Installation guide <span aria-hidden="true">→</span></span></a>
      <a class="pb-entry" href="getting_started.html"><span class="pb-entry-top"><span>02 / BUILD</span><b aria-hidden="true">↗</b></span><h3>Write your first model</h3><p>Define both levels, choose a solution method and understand the solver output.</p><span class="pb-entry-link">Step-by-step tutorial <span aria-hidden="true">→</span></span></a>
      <a class="pb-entry" href="case_library.html"><span class="pb-entry-top"><span>03 / APPLY</span><b aria-hidden="true">↗</b></span><h3>Explore energy cases</h3><p>Investigate grid vulnerability, robust energy dispatch and prediction-informed decisions.</p><span class="pb-entry-link">Browse the case library <span aria-hidden="true">→</span></span></a>
    </div>
  </section>

  <section class="pb-section" aria-labelledby="capabilities-heading">
    <div class="pb-section-heading"><div><p class="pb-eyebrow">MODELING &amp; SOLVING</p><h2 id="capabilities-heading">Built around the problems you study.</h2></div><p>A structured interface for complex decisions.</p></div>
    <div class="pb-feature-grid">
      <div class="pb-feature"><span class="pb-feature-icon" aria-hidden="true"><svg viewBox="0 0 32 32"><path d="m4 10 12-6 12 6-12 6Zm0 7 12 6 12-6M4 24l12 6 12-6"/></svg></span><h3>Integer decisions. Both levels.</h3><p>Model continuous and integer variables at the upper and lower levels, with automatic standard-form conversion and coupling-constraint handling.</p></div>
      <div class="pb-feature"><span class="pb-feature-icon pb-icon-orange" aria-hidden="true"><svg viewBox="0 0 32 32"><path d="M6 7h20M6 25h20M10 7v18M22 7v18"/><circle cx="10" cy="14" r="3"/><circle cx="22" cy="20" r="3"/></svg></span><h3>Optimistic &amp; pessimistic.</h3><p>Represent different assumptions about the follower's response with support for both bilevel solution perspectives.</p></div>
      <div class="pb-feature"><span class="pb-feature-icon pb-icon-orange" aria-hidden="true"><svg viewBox="0 0 32 32"><path d="m18 3-12 15h9l-2 11 13-17h-9Z"/></svg></span><h3>Choose how you solve.</h3><p>Use exact formulations based on KKT conditions or strong duality, or explore quick methods for your modeling workflow.</p></div>
      <div class="pb-feature"><span class="pb-feature-icon" aria-hidden="true"><svg viewBox="0 0 32 32"><path d="m16 3 11 5v8c0 6-7 11-11 13C12 27 5 22 5 16V8Z"/><path d="m10 16 4 4 8-9"/></svg></span><h3>Plan under uncertainty.</h3><p>Solve two-stage robust optimization problems using C&amp;CG. The current interface supports LP recourse; MIP recourse is planned.</p></div>
    </div>
  </section>

  <section class="pb-paper" aria-labelledby="paper-heading">
    <div class="pb-paper-aside"><p class="pb-eyebrow">THE RESEARCH</p><span class="pb-paper-year">2026</span><span>Proceedings of the CSEE</span></div>
    <div class="pb-paper-copy"><h2 id="paper-heading">Research you can build on.</h2><p>If PowerBiMIP supports your work, please cite our paper.</p><p class="pb-paper-title" lang="zh-CN">PowerBiMIP：面向电力能源系统优化的规范化双层混合整数规划建模与求解器</p><p class="pb-paper-authors" lang="zh-CN">吴晔敏 · 陆帅 · 顾伟 · 等</p><div class="pb-text-links"><a href="https://doi.org/10.13334/j.0258-8013.pcsee.261230">Read the paper <span aria-hidden="true">↗</span></a><a href="citation.html">Citation details <span aria-hidden="true">→</span></a></div></div>
  </section>

  <section class="pb-community" aria-labelledby="community-heading"><div><p class="pb-eyebrow">BUILT WITH THE COMMUNITY</p><h2 id="community-heading">Make your next model possible.</h2><p>Explore the code, share a case or help improve PowerBiMIP.</p></div><div class="pb-actions"><a class="pb-button pb-button-primary" href="https://github.com/GreatTM/PowerBiMIP/issues">Discuss on GitHub <span aria-hidden="true">↗</span></a><a class="pb-contact" href="mailto:yemin.wu@seu.edu.cn">Contact the team <span aria-hidden="true">→</span></a></div></section>
</div>

```{toctree}
:hidden:
:maxdepth: 2
:caption: Documentation

installation
getting_started
case_library
citation
```
