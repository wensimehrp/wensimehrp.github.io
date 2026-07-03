#import "../mod.typ": *
#show: wstemplate.with(
  title: "Using Typst as an SSG",
  description: "Beyond PDFs",
  created: datetime(year: 2026, month: 07, day: 29),
  tags: (),
  author: jeremy-gao,
)
This site you're seeing is built with Typst. Typst is the only dependency.

Before you read, please keep in mind that I don't have a lot of web development experience. I just graduated from high
school and sometimes I am extremely opinionated on certain technologies, for example JavaScript.

= How to Build a Site Today

Building a site today _correctly_ is... rather complicated. Many sites use at least one web framework or template
engine. I've used Jinja2, WebC, and Nunjucks, as well as Eleventy and Astro.

I've never liked any of them. All of them except Jinja2 require spinning up Node, installing a package manager, and
adding a bunch of files such as `packages.json` and `some-manager.lock`. I was using those frameworks without
understanding how they work most of the times. Sometimes I want a feature to work, so I tried reading the documentation
of the framework, but that feature is hidden in multiple layers of documents, so I quit and asked an AI instead -- and
LLMs don't give accurate and up-to-date info all the time. In fact I used LLM multiple times for configuring Tailwind
CSS in my site, but it always give outdated syntax for Tailwind CSS version 3 while I am using version 4.

Typst is also very complicated. It is a new language, so LLMs are bad at writing Tyspt, but I've been writing Typst for
a year, so I know more than the agents.

= Otter Docs
