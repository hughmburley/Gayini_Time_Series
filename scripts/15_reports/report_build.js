/* Gayini report batch — document builder.
   Reads one JSON record per unit from report_data.py. No number is typed here.
   Rendering traps that are load-bearing (do not "simplify"):
     1. every table needs TableLayoutType.FIXED and an exactly-summing grid, or Word autofit
        collapses the figure column;
     2. image paragraphs must carry NO line-spacing rule, or the picture renders at ~1/3 height. */
const fs=require('fs'), path=require('path');
const {Document,Packer,Paragraph,TextRun,Table,TableRow,TableCell,ImageRun,
  WidthType,ShadingType,BorderStyle,AlignmentType,PageOrientation,PageBreak,TableLayoutType}=require('docx');

const INK='0F3947',HEAD='26302E',BODY='3E4A46',MUTED='5F6B67',FAINT='8A8378',
      RUST='9C5B2E',GOLD='C79A3B',PANEL_A='F3EBDA',PANEL_W='EFEDE6',AEO_D='8A5F1E',GRN='2E6B2E';
const FONT='Georgia',SANS='Arial';
const CONTENT=15400,L=8500,GUT=320,R=6580,LW=7100,RW=7980,L4=10100,R4=4980;
const P=require('./paths');
const FIG=P.FIGS_DIR, UNITS=P.UNITS_DIR, OUTDIR=P.DOCS_DIR;
const FMETA=fs.existsSync(`${FIG}/figs_meta.json`)?JSON.parse(fs.readFileSync(`${FIG}/figs_meta.json`)):{};
const NONE={style:BorderStyle.NONE,size:0,color:'FFFFFF'},NOB={top:NONE,bottom:NONE,left:NONE,right:NONE};

const sizeOf=p=>{const b=fs.readFileSync(p);return{w:b.readUInt32BE(16),h:b.readUInt32BE(20)};};
const t=(x,o={})=>new TextRun({text:x,font:o.font||FONT,size:o.size||18,bold:!!o.bold,
  italics:!!o.italics,color:o.color||BODY,allCaps:!!o.caps,characterSpacing:o.track||0});
const p=(r,o={})=>new Paragraph({children:Array.isArray(r)?r:[r],
  spacing:{before:o.before||0,after:o.after===undefined?60:o.after,line:o.line||224},
  alignment:o.align||AlignmentType.LEFT});
const gap=(h=100)=>new Paragraph({children:[t('')],spacing:{before:0,after:h,line:20}});
const kicker=x=>p(t(x,{font:SANS,size:14,bold:true,color:RUST,caps:true,track:26}),{after:55});
const body=(x,o={})=>p(t(x,{size:18,color:o.color||BODY}),{after:o.after===undefined?85:o.after});
const rich=(parts,o={})=>p(parts.map(([s,oo])=>t(s,oo||{})),o);
const cap=x=>p(t(x,{size:14,italics:true,color:FAINT}),{after:40});
const rule=()=>new Paragraph({children:[t('')],spacing:{before:28,after:90,line:20},
  border:{bottom:{style:BorderStyle.SINGLE,size:8,color:GOLD,space:1}}});
const cell=(k,o={})=>new TableCell({children:k,width:{size:o.w,type:WidthType.DXA},
  shading:o.fill?{type:ShadingType.CLEAR,fill:o.fill,color:'auto'}:undefined,
  margins:{top:o.pad===undefined?110:o.pad,bottom:o.pad===undefined?110:o.pad,
           left:o.padx===undefined?150:o.padx,right:o.padx===undefined?150:o.padx},borders:NOB});
const table=(rows,widths)=>new Table({rows,columnWidths:widths,
  width:{size:widths.reduce((a,b)=>a+b,0),type:WidthType.DXA},
  layout:TableLayoutType.FIXED,borders:NOB});
const img=(file,wpx)=>{const d=sizeOf(file);
  return new Paragraph({children:[new ImageRun({type:'png',data:fs.readFileSync(file),
    transformation:{width:wpx,height:Math.round(wpx*d.h/d.w)}})],spacing:{before:0,after:35}});};
const titleBlock=(kick,name,sub)=>table([new TableRow({children:[cell([
  p(t(kick,{font:SANS,size:14,bold:true,color:GOLD,caps:true,track:36}),{after:50}),
  p(t(name,{size:38,bold:true,color:'FFFFFF'}),{after:55}),
  p(t(sub,{font:SANS,size:15,color:'D8E2E2'}),{after:40}),
  p(t('Internal review · not for external release · culturally sensitive — review with Nari Nari Tribal Council',
     {font:SANS,size:13,color:GOLD}),{after:0})],{w:CONTENT,fill:INK,pad:100,padx:185})]})],[CONTENT]);
const runHead=(name,pg)=>[table([new TableRow({children:[
  cell([p(t(name,{size:22,bold:true,color:HEAD}),{after:0})],{w:8200,pad:0,padx:0}),
  cell([p([t('Internal review · culturally sensitive   ',{font:SANS,size:12,color:RUST}),
           t(pg,{font:SANS,size:13,color:FAINT})],{after:0,align:AlignmentType.RIGHT})],
       {w:CONTENT-8200,pad:0,padx:0})]})],[8200,CONTENT-8200]),rule()];
const dt=(hs,rows,widths)=>table([
  new TableRow({children:hs.map((h,i)=>cell([p(t(h,{font:SANS,size:14,bold:true,color:'FFFFFF',caps:true,track:18}),{after:0})],
    {w:widths[i],fill:INK,pad:42}))}),
  ...rows.map((r,ri)=>new TableRow({children:r.map((c,i)=>cell(
    [p(t(String(c),{font:SANS,size:15,color:BODY}),{after:0})],
    {w:widths[i],fill:ri%2?'FFFFFF':PANEL_W,pad:30}))}))],widths);
const cards=items=>{const w=2620,g=320,widths=[];
  items.forEach((_,i)=>{widths.push(w); if(i<items.length-1) widths.push(g);});
  const kids=[];
  items.forEach((it,i)=>{kids.push(cell([
    p(t(it[0],{font:SANS,size:13,bold:true,color:MUTED,caps:true,track:18}),{after:45}),
    p(t(it[1],{size:30,bold:true,color:it[3]||MUTED}),{after:it[2]?25:0}),
    ...(it[2]?[p(t(it[2],{font:SANS,size:13,color:FAINT}),{after:0})]:[])],{w,fill:it[4]||PANEL_W,pad:95}));
    if(i<items.length-1) kids.push(cell([gap(10)],{w:g,pad:0,padx:0}));});
  return table([new TableRow({children:kids})],widths);};
const pb=()=>new Paragraph({children:[new PageBreak()],spacing:{before:0,after:0,line:20}});
const f1=n=>n.toFixed(1), f0=n=>Math.round(n).toString();
const nf=n=>n.toLocaleString('en-AU',{maximumFractionDigits:0});
const slug=s=>s.replace(/ /g,'_').replace(/\//g,'-');
const has=f=>fs.existsSync(f);
// "a", "a and b", "a, b and c" — no paddock currently has more than one trace community,
// but the clause is derived from a set difference, so it must not assume one.
const andList=a=>a.length<2?(a[0]||''):a.slice(0,-1).join(', ')+' and '+a[a.length-1];
// R-8 says a percentage that rounds to zero is never printed. That applies to a CLASSIFIED
// part too, not only to a trace: Bala 8/11's Riverine reaches the support rule (3.1 ha) and so
// must be counted and shown, but f0() rendered it "spans 2 kinds of country — 100% Inland
// Floodplain · 0% Riverine" — two kinds summing to 100 and 0. Both ends mislead, so both are
// bounded. Affects 1 of 64.
const pct=s=>s>0&&s<0.5?'under 1%':(s<100&&s>99.5?'over 99%':`${f0(s)}%`);
const CANNOT='What this can and cannot tell us. The satellite record measures cover, not condition — not whether it is native or introduced. Read it as "how much, and how green", never as a condition score.';

/* ---------------------------------------------------------------- paddock */
function paddockDoc(r){
  const g=slug(r.unit), F=n=>`${FIG}/${g}_${n}.png`;
  // R-8: page 1 lists the parts that reach the part-classification support rule — exactly the
  // rows page 3 shows — not every community in the census. Previously it listed the census
  // composition, so Bala 28ca announced "3 kinds of country ... 0% Aeolian" over a parts table
  // holding two rows. A community below the rule is a TRACE: named in a trailing clause, never
  // counted, never given a percentage.
  // Sorted share-descending to keep the established listing order: parts arrive ordered by
  // community name, composition was share-descending, and the two differ for 15 of 64. Without
  // this, R-8 would silently reorder page 1 in those 15 — a change nobody ruled on.
  const comp=r.parts.map(p=>({short:p.short,share:p.share})).sort((a,b)=>b.share-a.share);
  // R-12(b): joined with "and", not the middot. The middot is this batch's METADATA separator —
  // headers, card subtitles — so inside running prose it reads as a header fragment. With three
  // communities "80% Inland · 10% Riverine · 10% Aeolian" is not a sentence; the and-list is.
  const compTxt=andList(comp.map(c=>`${pct(c.share)} ${c.short}`));
  const trace=r.trace_communities||[];
  const traceNames=andList(trace.map(t=>t.short));
  const multi=r.parts.length>1;
  const kids=[];

  // ---- page 1
  kids.push(titleBlock('Paddock report',r.unit,
    `${nf(r.area_ha)} ha in scope  ·  ${r.conserved?'grazing removed':'grazed'}  ·  ${r.year_first}–${r.year_last} (${r.n_years} years)  ·  `+
    `${r.n_sites} monitoring ${r.n_sites===1?'site':'sites'}`),gap(90));
  const leftKids=[kicker('In plain terms'),
    rich([[plainTerms(r),{}]],{after:95}),rule(),
    kicker('The country it covers'),
    body(multi
      // R-12(a): numword, not a numeral. numword() is already the established usage across this
      // batch ("Ten monitoring sites sit inside…"), so a numeral here was inconsistent with the
      // register the reports already keep — a defect, not a style preference.
      ? `${r.unit} spans ${numword(comp.length)} kinds of country — ${compTxt}. `+
        (trace.length?`A few cells of ${traceNames} fall inside the boundary, too few to report on separately. `:'')+
        (r.area_treed_ha>1?`A further ${nf(r.area_treed_ha)} ha of woodland is left out of every figure here: tree canopy hides the ground beneath it. `:'')+
        `Because those kinds of country behave differently, the whole-paddock figures below are averages across places that are not alike.`
      // "entirely" is false wherever a trace exists — the second defect in this sentence.
      : (trace.length
          ? `${r.unit} is almost entirely ${comp[0].short} country, with a trace of ${traceNames} too small to report on separately. `+
            `The figures in this report describe it directly. `
          : `${r.unit} is entirely ${comp[0].short} country, so the figures in this report describe it directly. `)+
        (r.area_treed_ha>1?`A further ${nf(r.area_treed_ha)} ha of woodland is left out: tree canopy hides the ground beneath it.`:'')),
    rule(),kicker('The water'),
    rich([['Averaged across the paddock, ',{}],[r.unit,{}],[' was under water in ',{}],
      [`${f1(r.ff)}% of years`,{bold:true,color:INK}],
      [` — about ${Math.round(r.ff/100*r.n_years)} ${Math.round(r.ff/100*r.n_years)===1?'year':'years'} in ${r.n_years}. `,{}],
      [`That makes it ${ordinal(r.rank_ff)} wettest of the ${r.n_paddocks} paddocks.`,{}]],{after:90})];
  if(r.bands.length>1){
    const hi=r.bands[0],lo=r.bands[r.bands.length-1];
    leftKids.push(body(`It is not uniformly wet: the wettest ${nf(hi.ha)} ha floods in ${f0(hi.ff)}% of years while the driest `+
      `${nf(lo.ha)} ha floods in ${lo.ff<1?'under 1':f0(lo.ff)}%.`),gap(30),
      dt(['Wetness band','Area','Floods in'],r.bands.map(b=>[b.band,`${nf(b.ha)} ha`,`${f1(b.ff)}% of years`]),[3300,2400,2800]));
  }
  if(!multi && r.parts.length===1){
    const pt=r.parts[0];
    leftKids.push(gap(70),rule(),kicker('How this country is doing'),
      rich([['Because this paddock is one kind of country throughout, it can be compared directly against every other piece of ',{}],
        [pt.short,{}],[' country on Gayini. Its cover on the thinnest-covered twentieth is ',{}],
        [`${f0(pt.level)}%`,{bold:true,color:INK}],[`, ${rankPhrase(pt).replace('on the property','')}`,{}],
        [`, and over thirty-five years it is classified as `,{}],
        [stateLine(pt).toLowerCase(),{bold:true,color:pt.state==='Recovering'?GRN:(pt.state==='Unremarkable'?MUTED:RUST)}],
        ['.',{}]],{after:70}));
    if(pt.marginal||pt.robust_changed)
      leftKids.push(body(`That classification sits close to the boundary with the next description and would read differently under a slightly different cut — it is reported as classified, not as certain.`,{after:0}));
  }
  if(r.n_sites>0){
    leftKids.push(gap(70),kicker('Why this paddock matters'),
      body(sitesLine(r),{after:0}));
  }
  const rightKids=[];
  if(has(F('mapc1'))){
    rightKids.push(img(F('mapc1'),486),
      cap('Colour shows which kind of country the ground belongs to. Darker shading within each colour marks the wetter parts of that type.'));
  } else if(has(F('maploc'))){
    // Was: a `${g}_maploc.flags` sidecar that report_figs.py never writes, so `drawn`
    // was permanently false and the true branch was unreachable. The record of what the
    // map actually drew is figs_meta.json, which report_figs.py DOES write (:337) — read
    // it. A caption must not deny what the figure drew any more than promise what it did
    // not. Proven to fire BOTH ways by tests/test_caption_branches.py.
    const drawn=!!(FMETA[g]&&FMETA[g].sites_drawn);
    rightKids.push(img(F('maploc'),486),
      cap(`Where ${r.unit} sits, and which paddocks adjoin it.`
        +(drawn?' White squares are the monitoring sites reported here.'
          :(r.n_sites?` The ${numword(r.n_sites)} monitoring sites are listed on the last page; they are not drawn here because the stored paddock outline is too simplified to place them reliably.`:''))));
  } else if(has(F('comp'))){
    rightKids.push(img(F('comp'),470),
      cap('Top: what kind of country this paddock is made of. Bottom: how much of it sits in each wetness band, and how often each band floods.'));
  }
  kids.push(table([new TableRow({children:[
    cell(leftKids,{w:LW,pad:0,padx:0}),cell([gap(20)],{w:GUT,pad:0,padx:0}),
    cell(rightKids,{w:RW,pad:0,padx:0})]})],[LW,GUT,RW]),gap(80),
    cards([['Area in scope',`${nf(r.area_ha)} ha`,r.area_treed_ha>1?`plus ${nf(r.area_treed_ha)} ha woodland, excluded`:'non-treed ground',INK,PANEL_W],
      ['Floods in',`${f1(r.ff)}%`,`of years · ${ordinal(r.rank_ff)} wettest of ${r.n_paddocks}`,INK,PANEL_A],
      ['Thin-ground cover',`${f1(r.floor)}%`,multi?'an average of unlike parts':`${ordinal(r.rank_floor)} of ${r.n_paddocks}`,AEO_D,PANEL_W],
      ['Monitoring sites',`${r.n_sites}`,siteCard(r),r.n_sites?GRN:MUTED,PANEL_W]]));

  // ---- page 2 : the record
  const P=(n,tot)=>`Paddock report · page ${n} of ${tot}`;
  const NP=multi?5:4;
  kids.push(pb(),...runHead(`${r.unit} — the record`,P(2,NP)),
    body('Water is the thing that can be managed here, so it is the thing to read first. The top panel is how much of the paddock saw water each year; the bottom panel is what the ground cover did in response.',{after:100}),
    img(F('series'),990),
    cap('Blue bands mark wetter-than-average years. The green line is the cover on the thinnest-covered twentieth of the paddock — the number that separates good ground from poor. The dotted line is cover averaged across the whole paddock, which stays high and moves much less.'),
    gap(60),
    table([new TableRow({children:[
      cell([kicker('Reading the top panel'),
        body(`Water arrives here in pulses, not in a steady supply. The wettest single year on record was ${r.wettest_year}, when ${f0(r.wettest_ff)}% of the paddock saw water.`,{after:0})],{w:7540,pad:0,padx:0}),
      cell([gap(10)],{w:320,pad:0,padx:0}),
      cell([kicker('Reading the bottom panel'),
        body('The dotted line — cover averaged across the whole paddock — moves far less than the green line beneath it. That difference is the point: averages hide what is happening on the poorest ground.',{after:0})],{w:7540,pad:0,padx:0})]})],[7540,320,7540]),
    gap(70),
    cards([['Strongest year',`${r.best_year}`,`thin-ground cover ${f1(r.best_floor)}%`,GRN,PANEL_W],
      ['Weakest year',`${r.worst_year}`,`thin-ground cover ${f1(r.worst_floor)}%`,RUST,PANEL_W],
      ['Wettest year',`${r.wettest_year}`,`${f0(r.wettest_ff)}% of the paddock under water`,INK,PANEL_A]]));

  // ---- page 3 : the parts (multi only)
  let pg=3;
  if(multi){
    kids.push(pb(),...runHead(`${r.unit} — the ${r.parts.length===2?'two':'three'} parts of it`,P(3,NP)),
      rich([['Almost every figure elsewhere in this report is an average across the whole paddock. For ',{}],
        [r.unit,{}],[' that average hides more than it shows, because the paddock spans more than one kind of country — and ',{}],
        ['the parts do not behave alike.',{bold:true}]],{after:80}),
      body('Each kind of country has its own normal, so the fair question is not how a part compares with the paddock or with the property, but how it compares with the same kind of country elsewhere.',{after:55}),
      // REPORT-2 §3.3 — one sentence, fixed wording, no per-paddock composition.
      body('Within one kind of country, the drier parts carry less cover in their poorest patches. So the first comparison reflects how wet a part is as much as how it is faring. The second allows for that.',{after:80}),
      img(F('parts'),940),
      cap('Each grey dot is one part of one paddock somewhere on Gayini. The coloured diamonds are the parts of this paddock, placed against every other part of the same kind of country. The vertical line is what is typical for that country.'),
      gap(50),
      // REPORT-2 §3.1: BOTH comparison columns stay. The first is what the ground actually
      // carries; the second is what it carries relative to its water. Neither replaces the
      // other and nothing here may imply that one corrects the other.
      //
      // Ranks in both, never percentage points in the second. A 5 pp shortfall in wet country
      // and a 15 pp shortfall in dry country are not comparable quantities — the typical miss
      // runs from about 12.8 pp on the driest quarter of the property to 3.8 pp on the wettest.
      // A rank within community sidesteps that; percentage points would import it.
      dt(['This part of the paddock','Area','Cover on the thinnest twentieth','Compared with the same country elsewhere','For the water it gets',`Over ${r.n_years} years`],
        r.parts.map(pt=>[`${cape(pt.place)} — ${pt.short}`,pt.ha?`${nf(pt.ha)} ha`:'—',`${f0(pt.level)}%`,
          rankPhrase(pt),waterPhrase(pt),stateLine(pt)])
          .concat([[`Whole paddock (the average)`,`${nf(r.area_ha)} ha`,`${f0(r.floor)}%`,'—','—','—']]),
        [3400,1050,2150,2950,2950,2900]),
      gap(55),
      rich([['What this changes. ',{bold:true}],[partsVerdict(r),{}]],{after:0}));
    pg=4;
  }

  // ---- page 4/3 : how it compares
  kids.push(pb(),...runHead(`${r.unit} — how it compares`,P(pg,NP)),
    table([new TableRow({children:[
      cell([kicker('For how dry it is'),
        body('Across the property, how much cover a paddock carries tracks how often it floods — drier paddocks carry less. That relationship gives every paddock a fair expectation, and lets dry country be judged against dry country.',{after:70}),
        gap(30),
        cards([['Expected for its water',`${f1(r.predicted)}%`,'',MUTED,PANEL_W],
          ['What it carries',`${f1(r.floor)}%`,'',AEO_D,PANEL_A],
          ['Difference',`${r.residual>0?'+':'−'}${f1(Math.abs(r.residual))} pp`,'',r.residual<-r.fit.resid_sd?RUST:GRN,PANEL_W]]),
        gap(85),
        body(residualLine(r),{after:55}),
        // REPORT-2 §3.4, verbatim from the spec. A reader will take the slope of the
        // between-paddock line as what water buys HERE. It is not that quantity, and the
        // quantity it is mistaken for is about three times smaller. No figure is given for the
        // within-place response: it is unregistered and stays out of a deliverable.
        body('This line describes how paddocks differ from one another over the long run. It is not what an extra point of flooding would add to this paddock. That is a different and smaller number.',{after:80}),
        kicker('What this comparison does and does not do'),
        body('It does put a dry paddock alongside dry country rather than alongside the farm as a whole, which is the fairer test.',{after:55}),
        body(multi?'It does not separate the effect of country type from the effect of condition — this is a whole-paddock figure, so it averages the parts set out on page 3.':'It does not separate the effect of country type from the effect of condition.',{after:55}),
        body('And it says nothing at all about cause.',{after:0})],{w:L,pad:0,padx:0}),
      cell([gap(20)],{w:GUT,pad:0,padx:0}),
      cell([img(F('scatter'),416),
        cap(`Each dot is one paddock. The line is what cover to expect at a given amount of water — ${f1(r.fit.intercept)} + ${r.fit.slope.toFixed(3)} × flood %, read from the registry at render.`)],{w:R,pad:0,padx:0})]})],[L,GUT,R]),
    gap(35),
    table([new TableRow({children:[
      cell([kicker('What has changed'),
        rich(gapText(r),{after:85}),gap(20),
        rich([['One caution, and it matters. ',{bold:true}],
          ['Grazing was removed here in 2019. Anything this record shows before that date cannot be a consequence of it, and the record shows the country changing long before. The record shows what happened; it cannot show what caused it.',{}]],{after:95}),
        ...(r.conserved?[img(F('effect'),566),
          cap('The other conserved paddocks, on the same measure.')]:[])],{w:L,pad:0,padx:0}),
      cell([gap(20)],{w:GUT,pad:0,padx:0}),
      cell([img(F('gap'),416),
        cap(gapCaption(r))],{w:R,pad:0,padx:0})]})],[L,GUT,R]));

  // ---- last page : sites
  kids.push(pb(),...runHead(`${r.unit} — the monitoring sites`,P(NP,NP)));
  if(r.n_sites>0){
    kids.push(table([new TableRow({children:[
      cell([body(sitesIntro(r),{after:90}),
        img(F('sites'), r.n_sites>=8 ? 640 : 700),
        cap('Left: how often each site floods, coloured by the kind of country it sits in. Middle: what the ground at each site is made of. Right: these sites (diamonds) against every monitoring site of the same country type on the property.')],{w:L4,pad:0,padx:0}),
      cell([gap(20)],{w:GUT,pad:0,padx:0}),
      cell(unknowns(),{w:R4,fill:PANEL_W,pad:130,padx:140})]})],[L4,GUT,R4]),
      gap(r.n_sites>=8 ? 60 : 120),
      dt(['Site','Country','Floods in','Total cover','Green','Bare'],
        r.sites.map(s=>[s.plot_id,s.short,`${f1(s.ff)}%`,`${f1(s.tot)}%`,`${f1(s.green)}%`,`${f1(s.bare)}%`]),
        [1800,3600,2200,2700,2500,2600]),
      ...(r.n_sites>=8?[]:[gap(80),
      rich([['How to read this table. ',{bold:true}],
        ['Total cover is green growth plus standing dry material, averaged over the whole record. Green is the part of that which was photosynthesising when the satellite passed, so it moves with the season and the water; bare is what was left uncovered. A site with high total cover and low green is holding litter and dry material rather than growing — which in this country is normal for most of the year and not a fault.',{}]],{after:0})]));
  } else {
    kids.push(table([new TableRow({children:[
      cell([kicker('No monitoring sites fall inside this paddock'),
        body(`The monitoring network has ${r.network.nontreed} non-treed sites across Gayini — ${r.network.zoned_nontreed} of them inside a mapped paddock — and none sits inside ${r.unit}. Everything in this report therefore comes from the satellite record — the ${r.pixel_side_m.toFixed(2)}-metre grid covering the whole paddock — and none of it from ground measurement.`,{after:85}),
        body('That is a real limit rather than an oversight. Satellite cover can be checked against ground measurement where sites exist; here it cannot. Where this report gives a figure, read it as a measurement of how much cover the satellite sees, unverified on the ground.',{after:85}),
        kicker('What the satellite record still supports'),
        body(`Three things do not depend on having a site inside the boundary. How often the ground floods is measured across every ${r.pixel_side_m.toFixed(2)}-metre cell in the paddock. How much cover it carries is measured the same way, on the same grid used everywhere else on the property. And the comparison against other paddocks of the same wetness is made on that grid, so it is like-for-like whether or not a site happens to sit inside the fence.`,{after:85}),
        dt(['What is measured here','How','Checked on the ground'],
          [['How often it floods',`every ${r.pixel_side_m.toFixed(2)} m cell, ${r.n_years} years`,'no site inside this paddock'],
           ['How much cover it carries',`every ${r.pixel_side_m.toFixed(2)} m cell, ${r.n_years} years`,'no site inside this paddock'],
           ['How it compares with like country','the same grid, all 64 paddocks','not applicable']],
          [3400,3400,3300]),
        gap(95),
        kicker('Where the nearest ground measurement is'),
        body('The monitoring network was laid out to sample country types across the property, not to cover every paddock. Sites in the same kind of country elsewhere on Gayini are the closest available check on what the satellite reports here — the comparison figures earlier in this report place this paddock against exactly that group.',{after:85}),
        kicker('One arm of the property is missing from every report'),
        body('Fifteen monitoring sites on standard grazing fall outside every mapped management zone, so there is no paddock for them to belong to and no paddock report they can appear in. That is a third of the reportable network, and it is the arm the grazing comparison exists to measure. The exclusion is structural rather than a choice, and it applies to this report as much as to any other.',{after:0})],{w:L4,pad:0,padx:0}),
      cell([gap(20)],{w:GUT,pad:0,padx:0}),
      cell(unknowns(),{w:R4,fill:PANEL_W,pad:130,padx:140})]})],[L4,GUT,R4]));
  }
  kids.push(gap(45),rule(),
    p(t(CANNOT,{size:14,italics:true,color:MUTED}),{after:40}),
    p(t(`Scope. All headline figures use non-treed ground across the whole paddock, full record ${r.year_first}–${r.year_last}. `+
      (r.area_treed_ha>1?`${nf(r.area_treed_ha)} ha of woodland is excluded because tree canopy hides the ground beneath it. `:'')+
      `Paddock flood frequency is measured across every ${r.pixel_side_m.toFixed(2)} m cell; the site reports count a year as wet if any part of a site saw water, so the two will not match. `+
      `The expectation line and this paddock's difference from it are read from the results registry at render time, not recomputed. Source: Gayini_Results.sqlite.`,
      {size:13,color:FAINT}),{after:0}));
  return {kids,pages:NP};
}

/* --------------------------------------------------------------- helpers */
const cape=s=>s.charAt(0).toUpperCase()+s.slice(1);
function ordinal(n){const s=['th','st','nd','rd'],v=n%100;return n+(s[(v-20)%10]||s[v]||s[0]);}
function plainTerms(r){
  const rec=r.parts.filter(p=>p.state==='Recovering'), dec=r.parts.filter(p=>p.state==='Declining');
  if(rec.length&&r.parts.length>1)
    return `${r.unit} carries some of the most bare ground of its kind on Gayini — and ${rec.length===1?'part of it is':`${rec.length} of its ${r.parts.length} parts are`} coming back. `+
      `Over thirty-five years it has climbed from far below what its water would predict toward it.`;
  if(dec.length&&dec.length===r.parts.length)
    return `${r.unit} is well-watered country carrying ordinary cover for its type, and the record shows it losing ground slowly rather than gaining it.`;
  return `${r.unit} carries about the cover its water would predict, and the record over thirty-five years shows it holding rather than moving.`;
}
function sitesLine(r){
  return `${r.n_sites} of the property's monitoring sites sit inside ${r.unit}`+
    (r.n_sites_treed>0?`. ${r.n_sites_total} sites fall inside the boundary in total; ${r.n_sites_treed} sit under tree canopy, where the satellite cannot see the ground beneath, and are excluded from every figure in this report.`
      :`, so what this record shows can be checked against ground measurement.`);
}
/* R-16. The pattern lives here, not in the figure title, and it is derived per paddock.
   The title used to assert "Closing the gap" for all 64 — wrong for 45 of them.

   Follows the project's own standing rule, which this figure was breaking: where we describe a
   trend we give its slope and its correlation, and stop there. No p-value, no verdict.

   direction and gap_line_drawn come from the unit record, so this caption and the figure cannot
   disagree about whether there is a line to describe. */
function gapCaption(r){
  const sl=r.gap_slope_shown, rr=r.gap_r_derived;
  const src=r.gap_slope_registered!=null?', read from the results registry':'';
  // Same minus glyph on both numbers: toFixed() emits an ASCII hyphen, and "−0.003 ... -0.01"
  // inside one parenthesis is two different characters for one meaning.
  const sgn=(v,dp)=>`${v<0?'−':''}${Math.abs(v).toFixed(dp)}`;
  const num=`${sl>=0?'+':''}${sgn(sl,3)} points a year, correlation ${sgn(rr,2)}`;
  let s='One point per water year — no period boundaries. ';
  if(!r.gap_line_drawn)
    return s+`Year-to-year movement is larger than any trend running through it (${num}), so no `
            +`trend line is drawn: on this measure the paddock neither gained on the rest of the `
            +`property nor fell behind it.`;
  if(r.gap_direction==='closing')
    return s+`Across the record the difference narrowed (${num}${src}). The dashed line is that trend.`;
  if(r.gap_direction==='widening')
    return s+`Across the record the difference widened (${num}${src}). The dashed line is that trend.`;
  return s+`Across the record the difference neither narrowed nor widened to any degree the `
          +`record can distinguish (${num}${src}). The dashed line is that trend.`;
}
function siteCard(r){
  if(r.n_sites===0) return 'none inside this paddock';
  return r.n_sites_treed>0?`of ${r.n_sites_total}; ${r.n_sites_treed} treed, excluded`:'all reported';
}
function sitesIntro(r){
  let s=`${cape(numword(r.n_sites))} monitoring ${r.n_sites===1?'site sits':'sites sit'} inside ${r.unit}. Each has its own report.`;
  if(r.n_sites_treed>0)
    s=`${cape(numword(r.n_sites))} of the ${numword(r.n_sites_total)} monitoring sites here are reported. `+
      `${cape(numword(r.n_sites_treed))} sit under tree canopy, where the satellite cannot see the ground beneath, and are excluded from every figure in this report. Each reported site has its own report.`;
  return s;
}
function numword(n){return ['no','one','two','three','four','five','six','seven','eight','nine','ten',
  'eleven','twelve','thirteen'][n]||String(n);}
function rankPhrase(pt){
  const n=pt.rank, of=pt.n_of;
  if(n===1) return `lowest of ${of} on the property`;
  if(n===2) return `second-lowest of ${of}`;
  if(n<=of*0.25) return `among the lowest of ${of}`;
  if(n>=of*0.75) return `among the highest of ${of}`;
  return `${ordinal(n)} of ${of} — ordinary`;
}
// REPORT-2 §3.2. The wording is PRE-REGISTERED and this is a lookup on rank position, not
// composed prose: composed wording is how a caption acquires a claim nobody ruled on. Rank 1 =
// largest shortfall, within community, across all supported parts of that community.
//
// "High for its water" is NOT a condition claim. It means the part carries more cover than the
// fitted line predicts; page 4 already says what that does and does not mean, and nothing here
// attributes any position to grazing, conservation status or anything else.
function waterPhrase(pt){
  const n=pt.rank_water, of=pt.n_of, p=n/of;
  // A missing rank must HALT, never fall through. Every comparison against undefined is false,
  // so without this guard control reaches the last return and a part with no rank is labelled
  // "among the highest for its water" — the most favourable wording in the table. Found on the
  // first build: three unit records predated the column and Bala 29ca's Aeolian third, rank 1
  // of 17 and the WORST of its community, rendered as among the highest of 17. The chain of
  // ifs is exhaustive only for a finite rank; asserting that is cheaper than reordering it.
  if(!Number.isFinite(n)||!Number.isFinite(of)||of<1||n<1||n>of)
    throw new Error(`waterPhrase: ${pt.short} has no usable water rank (rank_water=${n}, `+
      `n_of=${of}). The unit record predates REPORT-2 — re-run report_data.py for this paddock.`);
  if(n===1) return `lowest of ${of} for its water`;
  if(n===2) return `second-lowest of ${of} for its water`;
  if(p<=0.10) return `among the lowest of ${of} for its water`;
  if(p<=0.25) return `low for its water — ${ordinal(n)} of ${of}`;
  if(p<=0.75) return `about what its water predicts — ${ordinal(n)} of ${of}`;
  if(p<=0.90) return `high for its water — ${ordinal(n)} of ${of}`;
  return `among the highest of ${of} for its water`;
}
function stateLine(pt){
  let s=pt.state.toLowerCase();
  if(pt.marginal||pt.robust_changed) s+=', marginally';
  return cape(s);
}
/* R-15, 5 Aug 2026. Two sets, not two counts.

   The old line asked `rec.length===low.length` — whether the number of recovering parts equals
   the number of bare ones — and then said "they are coming back", asserting that the BARE parts
   are the recovering ones. On Dinan 10 the bare parts are Aeolian and Inland Floodplain, both
   Persistently poor, and the one recovering part is Riverine at rank 6 of 37. It rendered:

     "Two of this paddock's three parts are among the most bare country of their kind anywhere
      on the property — and one of them are coming back."

   Three faults in one sentence: it attributes recovery to parts that are not recovering, the
   verb does not agree with its subject, and it gives no sense of scale — Dinan 10's recovery is
   58.9 ha of 841.1, 7% of the paddock, while the whole-paddock figure shows no change at all.

   One of the seven reports in this set manifests it. Bala 29ca's bare and recovering sets are
   genuinely identical, so the count test was right there by coincidence; Dinan 8 has no bare
   parts and takes the other branch; Bala 26ca and 28ca have neither. So this is a patch.

   Set membership decides the wording; area is stated whenever recovery sits outside the bare
   set, because that is exactly the case where a reader would otherwise scale it to the paddock. */
function partsVerdict(r){
  const rec=r.parts.filter(p=>p.state==='Recovering'), low=r.parts.filter(p=>p.rank<=2);
  const lowKey=new Set(low.map(p=>p.short));
  const both=rec.filter(p=>lowKey.has(p.short));        // bare AND coming back
  const outside=rec.filter(p=>!lowKey.has(p.short));    // coming back, but not among the bare
  const noneOf=n=>n===1?'it is not':(n===2?'neither is':'none of them is');
  let s='';
  if(low.length){
    s+=`${cape(numword(low.length))} of this paddock's ${numword(r.parts.length)} parts ${low.length===1?'is':'are'} among the most bare country of ${low.length===1?'its':'their'} kind anywhere on the property`;
    if(both.length&&both.length===low.length) s+=` — and ${low.length===1?'it is':'they are'} coming back. `;
    else if(both.length) s+=` — and ${numword(both.length)} of ${low.length===1?'them':'those'} ${both.length===1?'is':'are'} coming back. `;
    else s+=`, and ${noneOf(low.length)} coming back. `;
  }
  if(outside.length){
    const ha=outside.reduce((a,p)=>a+(p.ha||0),0), share=ha/r.area_ha*100;
    s+=`${s?'':`${cape(numword(outside.length))} of this paddock's parts ${outside.length===1?'is':'are'} coming back. `}`;
    if(s&&low.length) s+=`${cape(andList(outside.map(p=>p.short)))} ${outside.length===1?'is':'are'} coming back, but that is ${nf(ha)} ha — ${f0(share)}% of the paddock — and the whole-paddock figure does not move with it. `;
  }
  s+=`The whole-paddock figure of ${f0(r.floor)}% describes none of ${r.parts.length===2?'those two places':'those three places'} on its own. `+
     `Where this report gives a single number for the paddock, read it as an average across country that is not alike.`;
  const marg=r.parts.filter(p=>p.marginal||p.robust_changed);
  // Same defect class as R-15's, in the same function and in a report shipping today: with
  // three marginal parts this read "Aeolian and Inland Floodplain and Riverine SITS close to
  // the boundary ... IT IS reported as classified" — a chained join and a singular verb over a
  // plural subject. Dinan 8 is the only paddock in this set with more than one. R-15 says
  // "agree the verb"; this is that, and andList already exists.
  if(marg.length) s+=` ${cape(andList(marg.map(m=>m.short)))} ${marg.length===1?'sits':'sit'} close to the boundary between two of these descriptions, and would read differently under a slightly different cut — ${marg.length===1?'it is':'they are'} reported as classified, not as certain.`;
  return s;
}
function residualLine(r){
  const sd=r.fit.resid_sd;
  if(r.residual<-sd) return `Even allowing for how dry it is, ${r.unit} carries less cover than comparable country — ${ordinal(r.residual_rank)} lowest of the ${r.n_paddocks} paddocks on this measure.`;
  if(r.residual>sd) return `${r.unit} carries more cover than its water alone would predict, which places it above comparable country on the property.`;
  return `${r.unit} sits within the ordinary range of paddocks once its water is accounted for — its cover is close to what its wetness predicts.`;
}
function gapText(r){
  const sl=r.gap_slope_registered;
  if(sl!==null&&sl!==undefined&&sl>0.3)
    return [['Measured year by year against the rest of the property, ',{}],[r.unit,{}],
      [' has closed most of its gap, at ',{}],[`+${sl.toFixed(2)} points a year`,{bold:true,color:INK}],
      ['. It began the record far below every comparable paddock and now sits close to level. This is the clearest signal in the conserved set — the other three show no movement against grazed country at all.',{}]];
  return [['Measured year by year against the rest of the property, ',{}],[r.unit,{}],
    [' has neither closed nor widened its gap to any degree the record can distinguish. It sits where it has sat for thirty-five years.',{}]];
}
function unknowns(){return [kicker("What we don't know about this paddock"),
  body('Three things would change how this record should be read. None is in the data.',{after:70}),
  rich([['Land-use history — not recorded.',{bold:true,color:HEAD}]],{after:32}),
  body('Whether this country was ever cleared or cropped is not held anywhere in the record — the database reserves five columns for it and they are empty for all 64 paddocks. A satellite land-cover product was tested as a substitute and cannot supply one. Aerial photograph interpretation is underway.',{after:70}),
  rich([['Stocking history — not recorded.',{bold:true,color:HEAD}]],{after:32}),
  body('How heavily neighbouring paddocks were grazed, and when, is not held in the data used here.',{after:70}),
  rich([['Open water sits inside the cover measure.',{bold:true,color:HEAD}]],{after:32}),
  body('Standing water reads as low cover to the satellite. It is not removed.',{after:0})];}

/* ------------------------------------------------------------------ site */
function siteDoc(r){
  const g=slug(r.unit), F=n=>`${FIG}/${g}_${n}.png`;
  const kids=[titleBlock('Site report',r.unit,
    `${r.short} country  ·  ${f1(r.area_ha)} ha  ·  in ${r.paddock}  ·  ${r.series.year[0]}–${r.series.year[r.series.year.length-1]} (${r.n_years} years)`),gap(90)];
  const rightKids=has(F('smap'))
    ? [img(F('smap'),362),cap('Where the site sits. The black square is the site; the dashed ring is the surrounding kilometre. Darker blue = flooded in more years.')]
    : has(F('sflood'))
    ? [img(F('sflood'),430),cap('Top: which years this site saw water. Bottom: every monitoring site in the same kind of country, ordered driest to wettest, with this one marked.')]
    : [kicker('Where it sits'),body(`${r.unit} sits inside ${r.paddock}, in ${r.place}.`,{after:0})];
  kids.push(table([new TableRow({children:[
    cell([kicker('In plain terms'),
      rich([[`${r.unit} is a monitoring site in `,{}],[`${r.short} country`,{bold:true,color:AEO_D}],
        [`, ${r.place}. Over the full record it saw water in `,{}],
        [`${f1(r.ff)}% of years — ${numword(r.n_wet)} ${r.n_wet===1?'year':'years'} in ${r.n_years}`,{bold:true,color:INK}],
        [r.wet_years.length?`: ${r.wet_years.join(', ')}.`:'.',{}]],{after:90}),
      body(`Among the ${r.n_peers} ${r.short} sites on the property that places ${r.unit} ${ordinal(r.rank_ff)} wettest, against a middle site that floods in ${f1(r.peer_median_ff)}% of years.`),
      gap(30),
      cards([['Floods in',`${f1(r.ff)}%`,`of years · ${numword(r.n_wet)} in ${r.n_years}`,AEO_D,PANEL_A],
        ['Rank in its country',`${ordinal(r.rank_ff)}`,`of ${r.n_peers} ${r.short} sites`,AEO_D,PANEL_A],
        ['Typical cover',`${f1(r.tot)}%`,'green + dry material',MUTED,PANEL_W]])],{w:L,pad:0,padx:0}),
    cell([gap(20)],{w:GUT,pad:0,padx:0}),cell(rightKids,{w:R,pad:0,padx:0})]})],[L,GUT,R]),gap(115),
    table([new TableRow({children:[
      cell([kicker('How it sits among its own country'),
        body(`Comparing ${r.unit} with the other ${r.n_peers-1} ${r.short} sites is the fair comparison — the same kind of ground, the same expectations. On cover it ranks ${ordinal(r.rank_tot)} of ${r.n_peers}.`,{after:0})],{w:L,pad:0,padx:0}),
      cell([gap(20)],{w:GUT,pad:0,padx:0}),
      cell([img(F('speers'),380)],{w:R,pad:0,padx:0})]})],[L,GUT,R]),
    pb(),...runHead(`${r.unit} — the record`,'Site report · page 2 of 2'),
    rich([['Across the record total cover at ',{}],[r.unit,{}],[' averaged ',{}],
      [`${f1(r.tot)}%`,{bold:true,color:INK}],[' — made up of ',{}],
      [`${f1(r.green)}% green growth`,{bold:true}],
      [`, ${f1(r.dead)}% standing dry or dead material, and ${f1(r.bare)}% bare ground.`,{}]],{after:95}),
    img(F('sseries'),790),
    cap(`Total cover stays fairly steady here; it is the green fraction that moves with the water. The strongest year was ${r.best_year}–${String(r.best_year+1).slice(2)} at ${f1(r.best_tot)}% cover; the weakest ${r.worst_year}–${String(r.worst_year+1).slice(2)} at ${f1(r.worst_tot)}%.`),
    gap(85),
    table([new TableRow({children:[
      cell([kicker('The paddock it sits in'),
        body(`${r.unit} falls inside ${r.paddock}.`+
          (r.part_state?` The ${r.short} part of that paddock is classified as ${r.part_state_words} — this site is one measurement inside it, not a summary of it.`:'')+
          ` See the ${r.paddock} paddock report for the full picture.`,{after:80}),
        dt(['What the satellite sees','Share of the ground'],
          [['Green growth',`${f1(r.green)}%`],['Dry or dead material',`${f1(r.dead)}%`],['Bare ground',`${f1(r.bare)}%`]],
          [4600,3900])],{w:L,pad:0,padx:0}),
      cell([gap(20)],{w:GUT,pad:0,padx:0}),
      cell([kicker("What we don't know"),
        body('Land-use history for this site is not recorded. Whether this ground was ever cleared or cropped is not held anywhere in the data. Aerial photograph interpretation is underway.',{after:0})],{w:R,fill:PANEL_W,pad:110,padx:145})]})],[L,GUT,R]),
    gap(55),rule(),
    p(t(CANNOT,{size:14,italics:true,color:MUTED}),{after:40}),
    p(t(`Scope. Site figures use the ${f1(r.area_ha)} ha site footprint across the full record ${r.series.year[0]}–${r.series.year[r.series.year.length-1]}. A year counts as wet if any part of the site saw water — a different rule from the paddock report, so the two will not match. Source: Gayini_Results.sqlite.`,
      {size:13,color:FAINT}),{after:0}));
  return {kids,pages:2};
}

/* ---------------------------------------------------------------- write */
const props={page:{size:{orientation:PageOrientation.LANDSCAPE},
  margin:{top:520,bottom:440,left:700,right:700}}};
function write(kids,file){
  return Packer.toBuffer(new Document({styles:{default:{document:{run:{font:FONT,size:18,color:BODY}}}},
    sections:[{properties:props,children:kids}]})).then(b=>fs.writeFileSync(file,b));
}
(async()=>{
  fs.mkdirSync(OUTDIR,{recursive:true});
  const files=fs.readdirSync(UNITS).filter(f=>f.endsWith('.json')).sort();
  const made=[];
  for(const f of files){
    const r=JSON.parse(fs.readFileSync(path.join(UNITS,f)));
    const d=r.kind==='paddock'?paddockDoc(r):siteDoc(r);
    const name=r.kind==='paddock'
      ? `Gayini_paddock_report_${slug(r.unit)}.docx`
      : `Gayini_site_report_${r.unit}.docx`;
    await write(d.kids,path.join(OUTDIR,name));
    made.push(`${name}  (${d.pages} pp)`);
    console.log(`  ${name}`);
  }
  console.log(`\n${made.length} documents written to ${OUTDIR}`);
})();
