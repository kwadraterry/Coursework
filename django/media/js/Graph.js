 $(document).ready(function (){
console.log("u r monster");

var parse = d3.time.format("%d %b %Y").parse;
var data = [{date:"21 Jan 2000", pos:"101"},
            {date:"21 Feb 2000", pos:"105"},
            {date:"21 Mar 2000", pos:"1"},
            {date:"21 Apr 2000", pos:"109"},
            {date:"21 May 2000", pos:"111"},
            {date:"21 Jun 2000", pos:"31"},
            {date:"21 Jul 2000", pos:"90"},
            {date:"21 Aug 2000", pos:"43"},
            {date:"21 Sep 2000", pos:"121"},
           ].map(function(d){d.date = parse(d.date); d.pos = +d.pos; return d;});

console.log(data[0].date);

var margin = {top: 80, right: 80, bottom: 80, left: 80},
    width = 860 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;

var x = d3.time.scale().range([0, width]),
    y = d3.scale.linear().range([height, 0]),
    xAxis = d3.svg.axis().scale(x).tickSize(-height).tickSubdivide(true).orient("bottom"),
    yAxis = d3.svg.axis().scale(y).ticks(4).orient("left");

// An area generator, for the light fill.
//var area = d3.svg.area()
   // .interpolate("monotone")
    //.x(function(d) { return x(d.date); })
    //.y0(height)
    //.y1(function(d) { return y(d.pos); });

// A line generator, for the dark stroke.
var line = d3.svg.line()
    .interpolate("monotone")
    .x(function(d) { return x(d.date); })
    .y(function(d) { return y(d.pos); });

  // Compute the minimum and maximum date, and the maximum price.
  x.domain([data[0].date, data[data.length - 1].date]);
  y.domain([d3.max(data, function(d) { return d.pos; }),1]).nice();

  // Add an SVG element with the desired dimensions and margin.
  var svg = d3.select("#graph1").append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")")
      .on("click", click);

  // Add the clip path.
  svg.append("clipPath")
      .attr("id", "clip")
    .append("rect")
      .attr("width", width)
      .attr("height", height);

  // Add the area path.
  //svg.append("path")
      //.attr("class", "area")
      //.attr("clip-path", "url(#clip)")
      //.attr("d", area(data));

  // Add the x-axis.
  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis);

  // Add the y-axis.
  svg.append("g")
      .attr("class", "y axis")
      .call(yAxis);

  // Add the line path.
  svg.append("path")
      .attr("class", "line")
      .attr("clip-path", "url(#clip)")
      .attr("d", line(data));

   svg.selectAll(".dot")
    .data(data)
  .enter().append("circle")
    .attr("class", "dot")
    .attr("cx", line.x())
    .attr("cy", line.y())
    .attr("r", 2.0);

  // On click, update the x-axis.
  function click() {
    var n = data.length - 1,
        i = Math.floor(Math.random() * n / 2),
        j = i + Math.floor(Math.random() * n / 2) + 1;
    x.domain([data[i].date, data[j].date]);
    var t = svg.transition().duration(750);
    t.select(".x.axis").call(xAxis);
    //t.select(".area").attr("d", area(data));
    t.select(".line").attr("d", line(data));
  }
});