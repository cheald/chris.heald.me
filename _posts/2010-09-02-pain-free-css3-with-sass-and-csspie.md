---
layout: post
title: Pain-free CSS3 with Sass and CSSPie
categories:
- CSS
tags:
- chrome
- css
- css3
- csspie
- firefox
- internet explorer
- sass
status: publish
type: post
published: true
meta:
  _syntaxhighlighter_encoded: '1'
  _edit_last: '2'
  _wp_old_slug: ''
  dsq_thread_id: '335150422'
---
So, you have a great design for a site. Lots of rounded corners, soft shadows, and beautiful gradients. "This'll be fun!", you think.

Enter IE.

"Oh, crap", you think.

Modern web design in IE is a pain in the rear. Fortunately, we have modern tools that make it a not-pain.

* <a href="http://sass-lang.com/">SASS</a> (Syntactically Awesome Stylesheets) is a macro language for CSS. It lets you express CSS as nested rules, and gives you mix-ins, functionality extensions, variables, partials, and a whole lot more.
* <a href="http://css3pie.com/">CSSPie</a> is a set of behaviors for Internet Explorer that gives you CSS3 visual styles without really slow Javascript hacks like <a href="http://www.curvycorners.net/">CurvyCorners</a>.

When combined, the two are a shot of <em>liquid awesome</em> injected directly into your brain.

I've settled on a fairly standard setup for my projects. I have:

* My `application.sass` file.
* My `_mixins.sass` partial.
* My `PIE.htc` behavior file.

Macros is very straightforward:

~~~sass
@mixin pie
  behavior: url(/behaviors/PIE.htc)
.pie
  +pie

@mixin shadows($color: #aaa, $x: 1px, $y: 2px, $spread: 2px)
  @extend .pie
  -moz-box-shadow: $color $x $y $spread
  -webkit-box-shadow: $color $x $y $spread
  box-shadow: $color $x $y $spread

@mixin inset-shadows($color: #aaa, $x: 1px, $y: 1px, $spread: 1px)
  @extend .pie
  -moz-box-shadow: inset $x $y $spread $color
  -webkit-box-shadow: inset $x $y $spread $color
  box-shadow: inset $x $y $spread $color

@mixin corners($tl: 5px, $tr: nil, $br: nil, $bl: nil)
  @extend .pie
  @if $tr == nil
    $tr: $tl
  @if $br == nil
    $br: $tl
  @if $bl == nil
    $bl: $tl
  -moz-border-radius: $tl $tr $br $bl
  -webkit-border-top-left-radius: $tl
  -webkit-border-bottom-left-radius: $bl
  -webkit-border-top-right-radius: $tr
  -webkit-border-bottom-right-radius: $br
  border-radius: $tl $tr $br $bl

@mixin vertical-gradient($start: #000, $end: #ccc)
  @extend .pie
  background: $end
  background: -webkit-gradient( linear, left top, left bottom, color-stop(0, $start), color-stop(1, $end) )
  background: -moz-linear-gradient(center top, $start 0%, $end 100%)
  -pie-background: linear-gradient(90deg, $start, $end)
~~~

What's going on here? We're defining several mix-ins for Sass:

~~~sass
+shadows([color, [x, [y, [spread]]]])
+inset-shadows([color, [x, [y, [spread]]]])
+corners(size)
+corners(topleft, topright, bottomright, bottomleft)
+vertical-gradient(start, end)
~~~

Now, in your CSS, you can just do the following:

~~~sass
body
  font:
    family: Arial
    size: 10pt

.box
  +corners
  +shadows(#ccc)
  +vertical-gradient(#eee, #fff)

  h3
    color: #444

.dark-box
  +corners(20px)
  +shadows(#888, 4px, 4px, 4px)
  +vertical-gradient(#444, #000)
  color: #fff
  h3
    color: #fff

.box, .dark-box
  padding: 1em
  margin-bottom: 1em
~~~

This expands to:

~~~css
.pie, .box, .dark-box {
  behavior: url(/projects/PIE.htc);
}

body {
  font-family: Arial;
  font-size: 10pt;
}

.box {
  -moz-border-radius: 5px 5px 5px 5px;
  -webkit-border-top-left-radius: 5px;
  -webkit-border-bottom-left-radius: 5px;
  -webkit-border-top-right-radius: 5px;
  -webkit-border-bottom-right-radius: 5px;
  border-radius: 5px 5px 5px 5px;
  -moz-box-shadow: #cccccc 1px 2px 2px;
  -webkit-box-shadow: #cccccc 1px 2px 2px;
  box-shadow: #cccccc 1px 2px 2px;
  background: white;
  background: -webkit-gradient(linear, left top, left bottom, color-stop(0, #eeeeee), color-stop(1, white));
  background: -moz-linear-gradient(center top, #eeeeee 0%, white 100%);
  -pie-background: linear-gradient(270deg, #eeeeee, white);
}
.box h3 {
  color: #444444;
}

.dark-box {
  -moz-border-radius: 20px 20px 20px 20px;
  -webkit-border-top-left-radius: 20px;
  -webkit-border-bottom-left-radius: 20px;
  -webkit-border-top-right-radius: 20px;
  -webkit-border-bottom-right-radius: 20px;
  border-radius: 20px 20px 20px 20px;
  -moz-box-shadow: #888888 4px 4px 4px;
  -webkit-box-shadow: #888888 4px 4px 4px;
  box-shadow: #888888 4px 4px 4px;
  background: black;
  background: -webkit-gradient(linear, left top, left bottom, color-stop(0, #444444), color-stop(1, black));
  background: -moz-linear-gradient(center top, #444444 0%, black 100%);
  -pie-background: linear-gradient(270deg, #444444, black);
  color: white;
}
.dark-box h3 {
  color: white;
}

.box, .dark-box {
  padding: 1em;
  margin-bottom: 1em;
}
~~~

<a href="http://www.coffeepowered.net/projects/sass-mixins.php">Check out the live demo.</a>

Here are screenshots of the demo in Chrome 6, Firefox 4.0b3, Internet Explorer 8. Can you tell which browser is which?

<a href="http://www.coffeepowered.net/wp-content/uploads/2010/09/comps.png"><img src="http://www.coffeepowered.net/wp-content/uploads/2010/09/comps.png" alt="" title="comps" width="467" height="798" class="aligncenter size-full wp-image-323" /></a>
