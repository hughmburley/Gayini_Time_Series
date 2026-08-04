"""Gayini report batch — figures. One call per unit; nothing hardcoded.

The expectation line is drawn from the REGISTERED constants read by report_data,
never refitted (RS note 31 July, item 1).
"""
import json, os, glob, re, sqlite3
import numpy as np, pandas as pd
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.patheffects as pe
from PIL import Image
import geopandas as gpd

from config import DB, GPKG, FIGSRC_C1, FIGSRC_D2, FIGS_DIR as OUT, UNITS_DIR, require
require(DB,'Gayini_Results.sqlite'); require(GPKG,'Gayini_Results.gpkg')
INK,CREAM,GOLD,TEAL,BLUE,GREY='#0F3947','#F8F7F2','#C79A3B','#3B8A8F','#2165AC','#7C837E'
RUST,MUTED,FAINT,HEAD='#9C5B2E','#5F6B67','#8A8378','#26302E'
AEO_D,GRN_D,GRN_M,DRY,BARE='#8A5F1E','#2E6B2E','#5F9150','#C9B98C','#EAE3D2'
CM={'Aeolian Chenopod Shrublands':GOLD,'Riverine Chenopod Shrublands':TEAL,
    'Inland Floodplain Shrublands / Swamps':BLUE,'Floodplain Woodland / Forest':GREY}
CD={'Aeolian Chenopod Shrublands':AEO_D,'Riverine Chenopod Shrublands':'#2A6560',
    'Inland Floodplain Shrublands / Swamps':'#1B4E86'}
STATE_COL={'Recovering':'#2E6B2E','Declining':RUST,'Persistently poor':'#8A3324','Unremarkable':MUTED}
plt.rcParams.update({'font.family':'DejaVu Serif','font.size':9,
 'axes.edgecolor':FAINT,'axes.labelcolor':MUTED,'text.color':HEAD,'xtick.color':MUTED,
 'ytick.color':MUTED,'axes.spines.top':False,'axes.spines.right':False,'figure.facecolor':CREAM,
 'axes.facecolor':CREAM,'axes.grid':True,'grid.color':'#E3E0D8','grid.linewidth':.6,'axes.titlepad':7})
DPI=200
HALO=[pe.withStroke(linewidth=2.8,foreground=CREAM)]   # keeps annotation text readable over lines
HALO_S=[pe.withStroke(linewidth=2.2,foreground=CREAM)]
con=sqlite3.connect(f'file:{DB}?mode=ro',uri=True); con.execute('PRAGMA query_only=1')
CRS=8058                                   # canonical: GDA2020 NSW Lambert
_MZ=gpd.read_file(GPKG,layer='management_zones').to_crs(CRS)
_MZ['geometry']=_MZ.geometry.buffer(0)      # 12 of 64 stored invalid; buffer(0) repairs all
_PL=gpd.read_file(GPKG,layer='plots_current_summary').to_crs(CRS)

PADDOCK=pd.read_sql("""select z.zone_name,z.grazing_treatment,avg(f.veg_p05_spatial) floor,
  avg(f.flood_frac_pct) ff from fact_zone_veg_annual f join dim_management_zone z using(zone_fid)
  where f.series_variant='mean_of_seasons' and f.water_year between 1988 and 2022 group by 1,2""",con)
PARTS=pd.read_sql("select zone_name,community,level,state_registered from fact_zone_community_part_classification",con)
SITES=pd.read_sql("""select p.plot_id,p.simplified_vegetation_group community,
  avg(v.annual_wet_any)*100 ff,avg(v.mean_total_veg_pct) tot from v_plot_year_analysis_spine v
  join dim_plot p using(plot_id) where p.treed_plot_flag=0 group by 1,2""",con)

META={}

def save(fig,name):
    p=f'{OUT}/{name}.png'; fig.savefig(p,dpi=DPI,facecolor=CREAM); plt.close(fig)
    return p

def slug(s): return s.replace(' ','_').replace('/','-')

# Finding someone else's file is a different job from naming our own, and one slug
# cannot do both. The C1 checkerboard renders are named by
#   scripts/03_inundation_products/10_build_veg_regime_checkerboard.R:209
#   slugify <- function(s) gsub("[^A-Za-z0-9]+", "_", trimws(s))
# so a SOURCE lookup must use that rule. Using ours ('/' -> '-') silently missed the
# Bala 8/11 render and dropped the paddock to the locator fallback. Checked against all
# 64 zone_names: no collisions under either rule, and the two disagree only on the three
# slash-named zones (Bala 7/10, Bala 8/11, Bala 14/16). slug() still names OUR outputs.
def c1_slug(s): return re.sub(r'[^A-Za-z0-9]+', '_', s.strip())

# ------------------------------------------------------------------ paddock
def fig_series(r,tag):
    me=r['series']; yr=np.array(me['year']); ff=np.array(me['ff']); fl=np.array(me['floor']); mn=np.array(me['mean'])
    fig,ax=plt.subplots(2,1,figsize=(10,4.0),sharex=True,dpi=DPI,
        gridspec_kw={'height_ratios':[1,1.35],'hspace':.24,'left':.085,'right':.985,'top':.905,'bottom':.115})
    for A in ax:
        for y,v in zip(yr,ff):
            if v>ff.mean(): A.axvspan(y-.5,y+.5,color=BLUE,alpha=.08,lw=0)
    ax[0].plot(yr,ff,color=BLUE,lw=1.7,marker='o',ms=3)
    ax[0].axhline(ff.mean(),color=FAINT,ls='--',lw=.9)
    top=max(ff.max()*1.25,20); ax[0].set_ylim(-top*.06,top)
    # Record span derived, not typed. v1.1 fixed this class in report_build.js prose but
    # not here, and a figure annotation is client-facing text too (lint_builder.py, check A).
    ax[0].text(yr.max()+.3,ff.mean()+top*.07,f'{len(yr)}-year average {ff.mean():.0f}%',color=MUTED,fontsize=8,ha='right',path_effects=HALO)
    ax[0].set_ylabel('Share of paddock\nunder water (%)',fontsize=8.5)
    ax[0].set_title('How much of the paddock saw water each year',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    ax[1].fill_between(yr,0,fl,color=GRN_M,alpha=.32,lw=0)
    ax[1].plot(yr,fl,color=GRN_D,lw=2.0); ax[1].plot(yr,mn,color=MUTED,lw=1.2,ls=':')
    ax[1].set_ylim(0,108); ax[1].set_yticks([0,25,50,75,100])
    ax[1].annotate('cover averaged across the paddock',(yr[-4],mn[-4]),
        xytext=(yr.max()+.2,102),ha='right',va='top',color=MUTED,fontsize=8,path_effects=HALO,
        arrowprops=dict(arrowstyle='-',color=MUTED,lw=.7,shrinkA=2,shrinkB=3))
    ax[1].annotate('the thinnest-covered twentieth',(yr[2],fl[2]),
        xytext=(yr.min()+.2,max(fl.min()-14,3)),ha='left',va='bottom',color=GRN_D,fontsize=8,
        path_effects=HALO,arrowprops=dict(arrowstyle='-',color=GRN_D,lw=.7,shrinkA=2,shrinkB=3))
    ax[1].set_ylabel('Ground cover (%)',fontsize=8.5); ax[1].set_xlabel('Water year',fontsize=8.5)
    ax[1].set_title('What the ground cover did',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    ax[1].set_xlim(yr.min()-.5,yr.max()+.5)
    return save(fig,f'{tag}_series')

def fig_scatter(r,tag):
    S,I,SD=r['fit']['slope'],r['fit']['intercept'],r['fit']['resid_sd']
    fig,ax=plt.subplots(figsize=(5.4,3.5),dpi=DPI); fig.subplots_adjust(left=.135,right=.975,top=.875,bottom=.145)
    gz=PADDOCK[PADDOCK.grazing_treatment!='No grazing']; ng=PADDOCK[PADDOCK.grazing_treatment=='No grazing']
    xs=np.linspace(0,PADDOCK.ff.max()*1.05,50)
    ax.fill_between(xs,I+S*xs-SD,I+S*xs+SD,color=GREY,alpha=.14,lw=0)
    ax.plot(xs,I+S*xs,color=MUTED,lw=1.4)
    ax.scatter(gz.ff,gz.floor,s=22,color=GREY,alpha=.75,lw=0,label=f'grazed paddocks ({len(gz)})')
    ax.scatter(ng[ng.zone_name!=r['unit']].ff,ng[ng.zone_name!=r['unit']].floor,s=42,
               facecolor='none',edgecolor=INK,lw=1.3,label='conserved paddocks')
    x0,y0=r['ff'],r['floor']; pred=I+S*x0
    ax.plot([x0,x0],[y0,pred],color=RUST,ls=':',lw=1.4)
    ax.scatter([x0],[pred],s=46,facecolor='white',edgecolor=RUST,lw=1.4,zorder=5)
    ax.scatter([x0],[y0],s=130,color=RUST,marker='D',zorder=6,edgecolor='white',lw=1.3)
    dy=-6 if y0>pred else 3
    ax.annotate(r['unit'],(x0,y0),xytext=(x0+7,y0+dy),color=RUST,fontsize=9.5,fontweight='bold',
                va='center',path_effects=HALO,arrowprops=dict(arrowstyle='-',color=RUST,lw=1))
    ax.annotate('expected for its water',(x0,pred),xytext=(x0+7,pred-dy),color=RUST,fontsize=7.8,
                va='center',path_effects=HALO)
    ax.set_xlim(-3,PADDOCK.ff.max()*1.08); ax.set_ylim(PADDOCK.floor.min()-6,PADDOCK.floor.max()+6)
    ax.set_xlabel('How often the paddock floods (% of years)',fontsize=8.5)
    ax.set_ylabel('Cover on the thinnest-covered\ntwentieth (%)',fontsize=8.5)
    ax.set_title('Every paddock on Gayini, compared fairly',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    ax.legend(frameon=False,fontsize=7.5,loc='lower right')
    ax.text(.015,.965,f'line: {I:.1f} + {S:.3f} × flood %  ·  read from the registry at render',
            transform=ax.transAxes,fontsize=6.6,color=FAINT,va='top')
    return save(fig,f'{tag}_scatter')

def fig_gap(r,tag):
    yr=np.array(r['gap']['year']); v=np.array(r['gap']['value'])
    sl=r['gap_slope_registered']; b,a=np.polyfit(yr,v,1)
    if sl is not None: a=v.mean()-sl*yr.mean(); b=sl
    fit=a+b*yr
    fig,ax=plt.subplots(figsize=(5.4,3.4),dpi=DPI); fig.subplots_adjust(left=.165,right=.975,top=.865,bottom=.155)
    ax.axhline(0,color=MUTED,lw=1.2)
    ax.fill_between(yr,v,0,color=RUST,alpha=.16,lw=0)
    ax.plot(yr,v,color=RUST,lw=1.5,marker='o',ms=3.2)
    ax.plot(yr,fit,color=INK,lw=2.0,ls=(0,(5,3)))
    ax.set_ylim(min(v.min(),fit.min())-9,max(5,v.max()+5))
    ax.text(yr.min()+.4,fit[0]-6,f'{abs(fit[0]):.0f} points below',fontsize=8.4,color=INK,
            fontweight='bold',va='top',path_effects=HALO)
    ax.text(yr.max()-.2,fit[-1]+4.5,f'{abs(fit[-1]):.0f} points below',fontsize=8.4,color=INK,
            fontweight='bold',ha='right',va='bottom',path_effects=HALO)
    ax.text(yr.max()-.2,1.4,'level with the rest of the property',fontsize=7.4,color=MUTED,
            ha='right',path_effects=HALO)
    ax.set_xlim(yr.min()-.5,yr.max()+.5)
    ax.set_ylabel('Difference from the rest of\nthe property (points)',fontsize=8.5)
    ax.set_xlabel('Water year',fontsize=8.5)
    ax.set_title('Closing the gap, year by year',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    if sl is not None:
        ax.text(.985,1.012,f'trend +{sl:.3f} pp a year, read from the registry',transform=ax.transAxes,
                fontsize=6.8,color=FAINT,va='bottom',ha='right')
    return save(fig,f'{tag}_gap')

def fig_parts(r,tag):
    ps=[p for p in r['parts']]
    if len(ps)<2: return None   # single community degrades to prose, RS 31 Jul §5
    n=len(ps); fig,ax=plt.subplots(figsize=(11.0,1.35+1.0*n),dpi=DPI)
    fig.subplots_adjust(left=.20,right=.975,top=1-.42/(1.35+1.0*n)*1.6,bottom=.42/(1.35+1.0*n)*1.7)
    rng=np.random.default_rng(3)
    for i,p in enumerate(ps):
        y=n-1-i; k=p['community']
        pool=PARTS[PARTS.community==k]
        ax.scatter(pool['level'],y+rng.uniform(-.10,.10,len(pool)),s=26,color=GREY,alpha=.5,lw=0)
        med=pool['level'].median(); ax.vlines(med,y-.34,y+.16,color=MUTED,lw=1.6)
        ax.text(med,y-.40,f'typical {med:.0f}%',ha='center',va='top',fontsize=7.4,color=MUTED,path_effects=HALO_S)
        ax.scatter([p['level']],[y],s=190,color=CM[k],marker='D',edgecolor='white',lw=1.6,zorder=6)
        lab=f"{p['level']:.0f}%  ·  {p['state_words']}"
        room = (pool['level'].min() < p['level']-16)   # cloud extends left of the marker
        if room: ax.annotate(lab,(p['level'],y+.22),xytext=(p['level'],y+.22),ha='center',va='bottom',
                             fontsize=9,color=CD.get(k,HEAD),fontweight='bold',path_effects=HALO)
        else:    ax.annotate(lab,(p['level'],y),xytext=(p['level']-2.2,y),ha='right',va='center',
                             fontsize=9,color=CD.get(k,HEAD),fontweight='bold',path_effects=HALO)
    ax.set_yticks(range(n)); ax.set_yticklabels([f"{p['place'].capitalize()}\n({p['short']})" for p in ps][::-1],fontsize=9)
    ax.set_ylim(-.78,n-1+.72); ax.set_xlim(18,94)
    ax.set_xlabel('Cover on the thinnest-covered twentieth (%)',fontsize=8.5)
    ax.set_title('The parts of this paddock, each against its own kind of country',loc='left',
                 fontsize=11,color=HEAD,fontweight='bold')
    ax.grid(axis='y',visible=False)
    ax.scatter([],[],s=26,color=GREY,alpha=.5,lw=0,label='every other paddock-part of that kind on Gayini')
    ax.legend(frameon=False,fontsize=8,loc='lower right')
    return save(fig,f'{tag}_parts')

def fig_sites(r,tag):
    ss=r['sites']
    if not ss: return None
    df=pd.DataFrame(ss)
    fig,(axL,axM,axR)=plt.subplots(1,3,figsize=(13.2,max(4.4,1.05+.36*len(df))),dpi=DPI,
        gridspec_kw={'width_ratios':[1,1.05,.95]})
    fig.subplots_adjust(left=.072,right=.99,top=.865,bottom=.195,wspace=.12)
    y=np.arange(len(df))[::-1]
    axL.hlines(y,0,df.ff,color='#DCD6C8',lw=2.4)
    axL.scatter(df.ff,y,s=90,color=[CM[v] for v in df.community],zorder=4,edgecolor='white',lw=1)
    for yy,(_,x) in zip(y,df.iterrows()): axL.text(x.ff+.6,yy,f'{x.ff:.1f}%',va='center',fontsize=8,color=MUTED)
    axL.set_yticks(y); axL.set_yticklabels(df.plot_id,fontsize=8.4)
    axL.set_xlim(0,max(20,df.ff.max()*1.35)); axL.set_xlabel('How often the site floods (% of years)',fontsize=8.5)
    axL.set_title('How wet each site is',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    axL.grid(axis='y',visible=False)
    present=[k for k in CM if k in set(df.community)]
    axL.legend([Rectangle((0,0),1,1,color=CM[k]) for k in present],
               [k.split()[0] for k in present],frameon=False,fontsize=8,ncol=3,
               loc='upper center',bbox_to_anchor=(.5,-.125/max(1,len(df)/10)))
    left=np.zeros(len(df))
    for col,colr,lab in [('green',GRN_M,'green growth'),('dead',DRY,'dry / dead material'),('bare',BARE,'bare ground')]:
        axM.barh(y,df[col],left=left,color=colr,height=.62,label=lab,edgecolor=CREAM,lw=.6); left=left+df[col].values
    for yy,(_,x) in zip(y,df.iterrows()):
        axM.text(x.green/2,yy,f'{x.green:.0f}',va='center',ha='center',fontsize=7.6,color='white',fontweight='bold',path_effects=[pe.withStroke(linewidth=2.0,foreground=GRN_D)])
        axM.text(100-x.bare/2,yy,f'{x.bare:.0f}',va='center',ha='center',fontsize=7.6,color=MUTED)
    axM.set_yticks(y); axM.set_yticklabels([]); axM.set_xlim(0,100)
    axM.set_xlabel('Share of the ground (%)',fontsize=8.5)
    axM.set_title('What the ground is made of',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    axM.grid(axis='y',visible=False)
    axM.legend(frameon=False,fontsize=8,ncol=3,loc='upper center',bbox_to_anchor=(.5,-.125/max(1,len(df)/10)))
    order=[k for k in CM if k in set(SITES.community)]
    data=[SITES[SITES.community==k].tot.values for k in order]
    bp=axR.boxplot(data,positions=range(len(order)),widths=.52,patch_artist=True,showfliers=False,
        medianprops=dict(color=HEAD,lw=1.4),whiskerprops=dict(color=FAINT),capprops=dict(color=FAINT))
    for pch,k in zip(bp['boxes'],order):
        pch.set_facecolor(CM[k]); pch.set_alpha(.30); pch.set_edgecolor(CM[k]); pch.set_linewidth(1.2)
    rng=np.random.default_rng(7)
    for i,k in enumerate(order):
        v=SITES[SITES.community==k].tot.values
        axR.scatter(i+rng.uniform(-.13,.13,len(v)),v,s=16,color=GREY,alpha=.55,lw=0,zorder=3)
        mine=df[df.community==k]
        if len(mine): axR.scatter(i+rng.uniform(-.10,.10,len(mine)),mine.tot,s=72,marker='D',
                                  color=CM[k],edgecolor='white',lw=1.1,zorder=6)
    axR.set_xticks(range(len(order)))
    axR.set_xticklabels([f"{k.split()[0]}\n({(SITES.community==k).sum()} sites)" for k in order],fontsize=8.2)
    axR.set_ylabel('Total ground cover (%)',fontsize=8.5)
    axR.set_title('This paddock’s sites against all sites',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    axR.grid(axis='x',visible=False)
    axR.scatter([],[],s=72,marker='D',color=GREY,edgecolor='white',lw=1.1,label='sites in this paddock')
    axR.scatter([],[],s=16,color=GREY,alpha=.55,lw=0,label='all other sites')
    axR.legend(frameon=False,fontsize=8,ncol=2,loc='upper center',bbox_to_anchor=(.5,-.125/max(1,len(df)/10)))
    return save(fig,f'{tag}_sites')

def fig_effect(r,tag):
    res=pd.read_sql("""select z.zone_name,v.residual from v_zone_floor_flood_residual v
      join dim_management_zone z using(zone_fid) where z.grazing_treatment='No grazing'
      order by v.residual""",con)
    SD=r['fit']['resid_sd']
    fig,ax=plt.subplots(figsize=(9.0,2.55),dpi=DPI); fig.subplots_adjust(left=.145,right=.985,top=.845,bottom=.235)
    ax.axvspan(-SD,SD,color=GREY,alpha=.16,lw=0); ax.axvline(0,color=MUTED,lw=1.1)
    y=np.arange(len(res))[::-1]
    for i,(_,x) in zip(y,res.iterrows()):
        me=(x.zone_name==r['unit']); col=RUST if me else INK
        ax.hlines(i,0,x.residual,color=col,lw=2.0,alpha=.55)
        ax.scatter(x.residual,i,s=150 if me else 88,color=col,marker='D' if me else 'o',
                   zorder=5,edgecolor='white',lw=1.1)
        ax.text(x.residual-.8,i,f'{x.residual:+.1f}',ha='right',va='center',fontsize=8,color=col,fontweight='bold',path_effects=HALO)
    ax.set_yticks(y); ax.set_yticklabels(res.zone_name,fontsize=9.2)
    ax.set_xlim(res.residual.min()-6,10)
    ax.set_xlabel('Difference from what its water predicts (points)',fontsize=8.5)
    ax.set_title('The four paddocks where grazing has been removed',loc='left',fontsize=10.5,color=HEAD,fontweight='bold')
    ax.grid(axis='y',visible=False)
    ax.text(SD+.4,y.max()+.05,'ordinary range',fontsize=7.6,color=FAINT,va='center',path_effects=HALO_S)
    return save(fig,f'{tag}_effect')

def fig_map(r,tag):
    """Paddock locator map.

    Preference order:
      1. the registered C1 checkerboard render, if present on disk (best: carries vegetation);
      2. a locator built from management_zones + plots.
    The GeoPackage vegetation_units layer is NOT usable for mapping — see README §Known defects.
    """
    src=f"{FIGSRC_C1}/C1_veg_regime_paddock_{c1_slug(r['unit'])}_data.png"
    if os.path.exists(src):
        im=Image.open(src).convert('RGB')
        m=im.crop((150,230,1950,1900)); l=im.crop((2400,470,3280,1440)); g=64
        out=Image.new('RGB',(m.width+g+l.width,max(m.height,l.height)),(248,247,242))
        out.paste(m,(0,(out.height-m.height)//2)); out.paste(l,(m.width+g,(out.height-l.height)//2))
        META[tag]={'map_kind':'c1','sites_drawn':True,'neighbours_drawn':0,
                   'sites_expected':len(r['sites'])}
        p=f'{OUT}/{tag}_mapc1.png'; out.save(p); return p
    z=_MZ[_MZ.management_zone==r['unit']]
    if not len(z): return None
    bb=z.total_bounds
    if max(bb[2]-bb[0],bb[3]-bb[1])<50: return None       # degenerate geometry, no map
    fig,ax=plt.subplots(figsize=(6.6,4.4),dpi=DPI)
    fig.subplots_adjust(left=.012,right=.988,top=.99,bottom=.012)
    pad=max(bb[2]-bb[0],bb[3]-bb[1])*.30
    xlim=(bb[0]-pad,bb[2]+pad); ylim=(bb[1]-pad,bb[3]+pad)
    nb=_MZ[_MZ.management_zone!=r['unit']]
    nb=nb.cx[xlim[0]:xlim[1],ylim[0]:ylim[1]]
    nb=nb[nb.geometry.area>1e5]      # drop slivers that render as dark blobs
    if len(nb):
        nb.plot(ax=ax,color='#EDEAE1',edgecolor='#D6D1C4',lw=.9)
        for _,x in nb.iterrows():
            c=x.geometry.representative_point()
            if xlim[0]<c.x<xlim[1] and ylim[0]<c.y<ylim[1]:
                ax.text(c.x,c.y,x.management_zone,ha='center',va='center',fontsize=7,color='#A8A294',path_effects=HALO_S)
    conserved = r['conserved']
    z.plot(ax=ax,color=TEAL if conserved else GOLD,alpha=.28,edgecolor='none')
    z.boundary.plot(ax=ax,color=HEAD,lw=2.4)
    c=z.geometry.iloc[0].representative_point()
    ax.text(c.x,c.y,r['unit'],ha='center',va='center',fontsize=11,color=HEAD,fontweight='bold',path_effects=HALO)
    pl=_PL[_PL.plot_id.isin([s2['plot_id'] for s2 in r['sites']])]
    # Only draw sites when the GeoPackage polygon agrees with plot_paddock (the SOT).
    # 19 of 48 zoned plots fall outside their stored zone polygon — see README defects.
    if len(pl):
        zg=z.geometry.iloc[0]
        if not all(g.representative_point().within(zg) for g in pl.geometry): pl=pl.iloc[0:0]
    if len(pl):
        p2=pl.geometry.representative_point()
        ax.scatter(p2.x,p2.y,s=62,marker='s',facecolor='white',edgecolor=HEAD,lw=1.6,zorder=8)
        dy=(ylim[1]-ylim[0])*.024; dx=(xlim[1]-xlim[0])*.032
        # keep-out zones: scale bar (lower left) and legend (lower right)
        ko=[(xlim[0],ylim[0],xlim[0]+(xlim[1]-xlim[0])*.30,ylim[0]+(ylim[1]-ylim[0])*.13),
            (xlim[0]+(xlim[1]-xlim[0])*.58,ylim[0],xlim[1],ylim[0]+(ylim[1]-ylim[0])*.22),
            (xlim[0],ylim[1]-(ylim[1]-ylim[0])*.34,xlim[0]+(xlim[1]-xlim[0])*.26,ylim[1])]
        blocked=lambda X,Y: any(a<=X<=c and b<=Y<=d for a,b,c,d in ko)
        placed=[]
        for pid,px,py in sorted(zip(pl.plot_id,p2.x,p2.y),key=lambda t:(-t[2],t[1])):
            best=None
            for k in range(10):
                for sgn,ha in ((1,'center'),(-1,'center')):
                    tx=px; ty=py+sgn*dy*(1+k*0.85)
                    if blocked(tx,ty): continue
                    if any(abs(tx-qx)<dx*1.8 and abs(ty-qy)<dy*1.1 for qx,qy,_ in placed): continue
                    best=(tx,ty,ha); break
                if best: break
                for sgn,ha in ((1,'left'),(-1,'right')):
                    tx=px+sgn*dx*(0.9+k*0.5); ty=py
                    if blocked(tx,ty): continue
                    if any(abs(tx-qx)<dx*1.8 and abs(ty-qy)<dy*1.1 for qx,qy,_ in placed): continue
                    best=(tx,ty,ha); break
                if best: break
            if not best: best=(px,py+dy,'center')
            placed.append(best)
            ax.annotate(pid,(px,py),xytext=(best[0],best[1]),ha=best[2],va='center',
                        fontsize=7.2,color=HEAD,path_effects=HALO_S,zorder=9,
                        arrowprops=dict(arrowstyle='-',color=HEAD,lw=.5,alpha=.5,shrinkA=1,shrinkB=5))
    ax.set_xlim(*xlim); ax.set_ylim(*ylim); ax.set_axis_off(); ax.set_facecolor(CREAM)
    span=xlim[1]-xlim[0]; step=2000 if span>9000 else (1000 if span>4000 else 500)
    x0=xlim[0]+span*.045; y0=ylim[0]+(ylim[1]-ylim[0])*(.10 if (r['sites'] and not len(pl)) else .05)
    ax.plot([x0,x0+step],[y0,y0],color=HEAD,lw=2.8,solid_capstyle='butt')
    ax.text(x0+step/2,y0+(ylim[1]-ylim[0])*.018,
            f'{step/1000:g} km' if step>=1000 else f'{step} m',ha='center',fontsize=8,color=HEAD)
    ins=fig.add_axes([.008,.66,.235,.33]); ins.set_axis_off(); ins.set_facecolor(CREAM)
    _MZ.plot(ax=ins,color='#F0EDE4',edgecolor='#D6D1C4',lw=.3)
    z.plot(ax=ins,color=RUST,lw=0)
    tb=_MZ.total_bounds; ins.set_xlim(tb[0],tb[2]); ins.set_ylim(tb[1],tb[3])
    ins.text(.5,-.06,'where it sits on Gayini',transform=ins.transAxes,ha='center',fontsize=7.4,color=MUTED)
    hs=[Rectangle((0,0),1,1,color=TEAL if conserved else GOLD,alpha=.28)]
    lb=['this paddock']
    if len(nb): hs.append(Rectangle((0,0),1,1,color='#EDEAE1')); lb.append('neighbouring paddocks')
    if len(pl):
        hs.append(plt.Line2D([],[],marker='s',color='none',markerfacecolor='white',
                  markeredgecolor=HEAD,markeredgewidth=1.6,markersize=7)); lb.append('monitoring site')
    ax.legend(hs,lb,frameon=True,facecolor=CREAM,edgecolor='#DCD6C8',fontsize=8.4,
              loc='lower right',framealpha=.94,borderpad=.7)
    if r['sites'] and not len(pl):
        ax.text(.015,.012,'site locations not shown — stored outline too simplified to place them',
                transform=ax.transAxes,ha='left',va='bottom',fontsize=7,color=FAINT,path_effects=HALO_S)
    META[tag]={'map_kind':'locator','sites_drawn':bool(len(pl)),
               'neighbours_drawn':int(len(nb)),'sites_expected':len(r['sites'])}
    return save(fig,f'{tag}_maploc')

def fig_comp(r,tag):
    """Always-available page-1 figure: what the paddock is made of, and how wet each band is."""
    comp=[c for c in r['composition'] if c['short']!='Woodland']
    bands=r['bands']
    fig,(a1,a2)=plt.subplots(2,1,figsize=(6.4,3.6),dpi=DPI,
        gridspec_kw={'height_ratios':[max(1,len(comp)),max(1,len(bands))],'hspace':.85})
    fig.subplots_adjust(left=.30,right=.965,top=.885,bottom=.10)
    y=np.arange(len(comp))[::-1]
    a1.barh(y,[c['share'] for c in comp],color=[CM.get(c['community'],GREY) for c in comp],height=.60)
    for yy,c in zip(y,comp):
        a1.text(c['share']+1.2,yy,f"{c['share']:.0f}%  ·  {c['ha'] if False else ''}".strip(' ·'),
                va='center',fontsize=8.4,color=MUTED)
    a1.set_yticks(y); a1.set_yticklabels([c['short'] for c in comp],fontsize=8.6)
    a1.set_xlim(0,105); a1.set_xlabel('Share of the paddock (%)',fontsize=8)
    a1.set_title('What kind of country this is',loc='left',fontsize=10,color=HEAD,fontweight='bold')
    a1.grid(axis='y',visible=False)
    yb=np.arange(len(bands))[::-1]
    a2.barh(yb,[b['ha'] for b in bands],color=[BLUE if b['ff']>20 else (TEAL if b['ff']>5 else GOLD) for b in bands],height=.60)
    for yy,b in zip(yb,bands):
        a2.text(b['ha']*1.03,yy,f"{b['ff']:.0f}% of years",va='center',fontsize=8.4,color=MUTED)
    a2.set_yticks(yb); a2.set_yticklabels([b['band'] for b in bands],fontsize=8.6)
    a2.set_xlim(0,max(b['ha'] for b in bands)*1.42)
    a2.set_xlabel('Area (ha)',fontsize=8)
    a2.set_title('How wet each part of it is',loc='left',fontsize=10,color=HEAD,fontweight='bold')
    a2.grid(axis='y',visible=False)
    return save(fig,f'{tag}_comp')

# ------------------------------------------------------------------ site
def fig_site_series(r,tag):
    s=r['series']; yr=np.array(s['year'])
    gr,de,ba=np.array(s['green']),np.array(s['dead']),np.array(s['bare'])
    fig,ax=plt.subplots(figsize=(10,3.5),dpi=DPI); fig.subplots_adjust(left=.075,right=.985,top=.855,bottom=.215)
    for y,w in zip(yr,s['wet']):
        if w: ax.axvspan(y-.5,y+.5,color=BLUE,alpha=.16,lw=0); ax.text(y,101.5,'wet',ha='center',fontsize=7,color=BLUE)
    ax.fill_between(yr,0,gr,color=GRN_M,alpha=.95,label='green growth',lw=0)
    ax.fill_between(yr,gr,gr+de,color=DRY,label='dry / dead material',lw=0)
    ax.fill_between(yr,gr+de,100,color=BARE,label='bare ground',lw=0)
    ax.plot(yr,np.array(s['tot']),color=GRN_D,lw=1.4)
    ax.set_ylim(0,108); ax.set_yticks([0,25,50,75,100]); ax.set_xlim(yr.min()-.5,yr.max()+.5)
    ax.set_ylabel('Share of the ground (%)',fontsize=8.5); ax.set_xlabel('Water year',fontsize=8.5)
    ax.set_title(f"What the ground looked like at {r['unit']}, {yr.min()}–{yr.max()+1}",loc='left',
                 fontsize=10.5,color=HEAD,fontweight='bold')
    ax.legend(frameon=False,fontsize=8.4,ncol=3,loc='upper center',bbox_to_anchor=(.5,-.145)); ax.grid(False)
    return save(fig,f'{tag}_sseries')

def fig_site_peers(r,tag):
    peers=SITES[SITES.community==r['community']]
    fig,ax=plt.subplots(figsize=(5.4,3.3),dpi=DPI); fig.subplots_adjust(left=.145,right=.975,top=.865,bottom=.16)
    oth=peers[peers.plot_id!=r['unit']]
    ax.scatter(oth.ff,oth.tot,s=38,color=GREY,alpha=.7,lw=0,label=f'other {r["short"]} sites ({len(oth)})')
    ax.scatter([r['ff']],[r['tot']],s=145,color=CM[r['community']],marker='D',
               edgecolor=CD.get(r['community'],HEAD),lw=1.5,zorder=5)
    ax.annotate(r['unit'],(r['ff'],r['tot']),xytext=(r['ff']+peers.ff.max()*.10,r['tot']+.9),
                color=CD.get(r['community'],HEAD),fontsize=9.5,fontweight='bold',va='center',
                path_effects=HALO,arrowprops=dict(arrowstyle='-',color=CD.get(r['community'],HEAD),lw=1))
    ax.set_xlim(-3,peers.ff.max()*1.12)
    ax.set_xlabel('How often the site floods (% of years)',fontsize=8.5)
    ax.set_ylabel('Total ground cover (%)',fontsize=8.5)
    ax.set_title(f'{r["unit"]} among the {len(peers)} {r["short"]} sites',loc='left',
                 fontsize=10.5,color=HEAD,fontweight='bold')
    ax.legend(frameon=False,fontsize=8,loc='lower right')
    return save(fig,f'{tag}_speers')

def fig_site_flood(r,tag):
    """Always-available: the site's 35-year wet/dry record and where it sits among its peers."""
    s=r['series']; yr=np.array(s['year']); wet=np.array(s['wet'])
    fig,(a1,a2)=plt.subplots(2,1,figsize=(6.0,3.5),dpi=DPI,gridspec_kw={'height_ratios':[1,1.15],'hspace':.85})
    fig.subplots_adjust(left=.135,right=.965,top=.885,bottom=.135)
    a1.bar(yr,wet,width=.82,color=[BLUE if w else '#E3E0D8' for w in wet])
    a1.set_ylim(0,1.35); a1.set_yticks([])
    a1.set_xlim(yr.min()-.6,yr.max()+.6); a1.set_xlabel('Water year',fontsize=8)
    for y,w in zip(yr,wet):
        if w: a1.text(y,1.06,str(y+1)[2:],ha='center',fontsize=6.4,color=BLUE)
    a1.set_title(f"The years this site saw water — {r['n_wet']} of {r['n_years']}",loc='left',
                 fontsize=10,color=HEAD,fontweight='bold')
    a1.grid(False)
    peers=SITES[SITES.community==r['community']].sort_values('ff')
    yy=np.arange(len(peers))
    cols=[CM[r['community']] if p==r['unit'] else '#DCD6C8' for p in peers.plot_id]
    a2.bar(yy,peers.ff,color=cols,width=.72)
    a2.set_xticks([]); a2.set_ylabel('Floods in (% of years)',fontsize=8)
    a2.set_xlabel(f"the {len(peers)} {r['short']} sites, driest to wettest",fontsize=8)
    k=list(peers.plot_id).index(r['unit'])
    a2.annotate(r['unit'],(k,peers.ff.iloc[k]),xytext=(k,peers.ff.iloc[k]+peers.ff.max()*.11),
                ha='center',fontsize=8.6,color=CD.get(r['community'],HEAD),fontweight='bold',path_effects=HALO)
    a2.set_ylim(0,peers.ff.max()*1.24)
    a2.set_title('How wet it is compared with its own country',loc='left',fontsize=10,color=HEAD,fontweight='bold')
    a2.grid(axis='x',visible=False)
    return save(fig,f'{tag}_sflood')

def fig_site_map(r,tag):
    src=f"{FIGSRC_D2}/D2_site_{r['unit']}_slide_data.png"
    if not os.path.exists(src): return None
    im=Image.open(src).convert('RGB'); W,H=im.size
    im=im.crop((0,int(.03*H),int(.40*W),int(.60*H)))
    p=f'{OUT}/{tag}_smap.png'; im.save(p); return p

if __name__=='__main__':
    made={}
    for f in sorted(glob.glob(os.path.join(UNITS_DIR,'*.json'))):
        r=json.load(open(f)); tag=slug(r['unit'])
        if r['kind']=='paddock':
            got={k:v for k,v in [('map',fig_map(r,tag)),('comp',fig_comp(r,tag)),('series',fig_series(r,tag)),
                 ('parts',fig_parts(r,tag)),('scatter',fig_scatter(r,tag)),('gap',fig_gap(r,tag)),
                 ('effect',fig_effect(r,tag) if r['conserved'] else None),('sites',fig_sites(r,tag))] if v}
        else:
            got={k:v for k,v in [('smap',fig_site_map(r,tag)),('sflood',fig_site_flood(r,tag)),('sseries',fig_site_series(r,tag)),
                 ('speers',fig_site_peers(r,tag))] if v}
        made[r['unit']]=sorted(got)
        print(f"  {r['unit']:12s} {len(got)} figs: {', '.join(sorted(got))}")
    json.dump(made,open(os.path.join(OUT,'figs_made.json'),'w'),indent=1)
    json.dump(META,open(f'{OUT}/figs_meta.json','w'),indent=1)
