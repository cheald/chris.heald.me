---
layout: post
title: 'For the beginner: Top Ten things to know about Rails'
categories: []
tags: []
status: draft
type: post
published: false
meta:
  _edit_last: '2'
---
One of the things I've quickly forgotten is that Rails had a much steeper learning curve than a lot of programming hurdles that I've faced. This is primarily because it's <a href="http://gettingreal.37signals.com/ch04_Make_Opinionated_Software.php">opinionated software</a>. It has its likes and dislikes, and if you aren't aware of them, you're going to spend an awful lot of time and effort running around in circles reinventing invented wheels. With further ado, here are a few of the hurdles that people might need help over.

### 1. Rails imposes an MVC design structure on you.

You see it all over the place, but what's that mean? MVC, or "Model, View, Controller" is an application design mechanism that splits different responsibilities into different pieces.

The <strong>Model</strong> is responsible for representing your data. In a Rails app, a Model maps to one row in the database (via a framework called <em>ActiveRecord</em>, which is an object-relational mapping layer. You don't need to remember that right this instant.) Models are responsible for modeling data, and relationships between data, and nothing else.

The <strong>View</strong> is responsible for displaying your data to the user. It doesn't do anything to change or update data - it's like a translator, who takes what your controller says and translates it. It doesn't decide what to say, just how to say it. In the Rails world, you would receive data from a <em>controller action</em>, and can choose to render it in HTML, XML, JSON, YAML, or whatever you like.

The <strong>Controller</strong> is the driver of your application. It takes input from the user, makes decisions about it, possibly updates or creates Model instances, then passes data to the View for rendering.

Let's assume that you want to write a simple little application that stores notes for later. Your application will have the following:

* A "Note" model, which represents a single note. It will have fields like "note_body" and "created_at".
* A "Notes" controller, which is responsible for creating, updated, and deleting notes. It will have controller actions like "new" and "edit". The user may invoke those actions by visiting certain URLs.
* A view for each of your Notes actions. You'll have a "new" view, an "edit" view, and so on.

This may seem like an awful lot of work if you come from a non-MVC background, but it rapidly proves its worth. By stratifying your application's design, maintenance and extension becomes far, far easier than it might be otherwise.

### 2. If it's too hard, you're probably doing it wrong.

