clear;clc;close all

clear;clc;close all

set(groot,'defaultFigureColor','w')
set(groot,'defaultAxesFontName','Times New Roman')
set(groot,'defaultTextFontName','Times New Roman')
set(groot,'defaultAxesFontSize',12)
set(groot,'defaultTextFontSize',12)
set(groot,'defaultAxesLineWidth',1)
set(groot,'defaultLineLineWidth',1.5)
set(groot,'defaultAxesBox','on')

%% user inputs

fileName='Bare_drop_10in.xlsx';

% manually choose sheets here
sheetNames={'trial048','trial052'};

% acceleration axis to analyze
axisName='az_mps2'; % 'ax_mps2','ay_mps2','az_mps2'
timeName='t_us';
timeScale=1e-6;

% auto window starts just after largest impact spike
% if the window looks bad, switch to false and enter manual windows below
useAutoWindow=false;

% manual windows in seconds, one row per sheet: [tStart_s tEnd_s]
manualWindows=[
    0.502 0.540
    0.502 0.540
];

% frequency search limits
fMin=100;       % Hz, raised to avoid low-frequency rebound/drift
fMaxUser=1500; % Hz, code also limits based on sampling rate

% envelope/log-decrement style fit settings
bandFrac=0.25;       % bandpass around FFT peak: +/-25%
minPeakFrac=0.08;    % ignore tiny envelope peaks

outDir='damping_check_outputs';
if ~exist(outDir,'dir')
    mkdir(outDir)
end

results=table;

%% analyze selected sheets

for ss=1:length(sheetNames)

    sheetName=sheetNames{ss};

    T=readtable(fileName,'Sheet',sheetName,'VariableNamingRule','preserve');

    names=T.Properties.VariableNames;

    tCol=find(strcmp(names,timeName),1);
    yCol=find(strcmp(names,axisName),1);

    if isempty(tCol)
        error('Could not find time column "%s" in sheet %s.',timeName,sheetName)
    end

    if isempty(yCol)
        error('Could not find axis column "%s" in sheet %s.',axisName,sheetName)
    end

    tRaw=T{:,tCol};
    yRaw=T{:,yCol};

    good=isfinite(tRaw) & isfinite(yRaw);
    t=tRaw(good)*timeScale;
    y=yRaw(good);

    t=t-t(1);
    y=y-mean(y(1:min(200,length(y)))); % baseline correction

    dt=median(diff(t));
    fs=1/dt;
    fMax=min(fMaxUser,0.45*fs);

    %% choose ringdown window

    if useAutoWindow
        [~,impactIdx]=max(abs(y));
        tImpact=t(impactIdx);

        % starts after main impact spike
        tStart=tImpact+0.001;
        tEnd=tImpact+0.025;
    else
        tStart=manualWindows(ss,1);
        tEnd=manualWindows(ss,2);
    end

    idx=t>=tStart & t<=tEnd;

    if sum(idx)<20
        warning('Sheet %s has too few samples in selected window. Skipping.',sheetName)
        continue
    end

    tWin=t(idx);
    yWin=y(idx);
    yWin=detrend(yWin);
    tWin=tWin-tWin(1);

    %% FFT of selected ringdown window

    N=length(yWin);
    win=hann(N);
    yFFT=yWin(:).*win(:);

    Y=fft(yFFT);
    P2=abs(Y/N);
    P1=P2(1:floor(N/2)+1);
    P1(2:end-1)=2*P1(2:end-1);

    f=fs*(0:floor(N/2))/N;

    bandIdx=find(f>=fMin & f<=fMax);

    if isempty(bandIdx)
        warning('No valid FFT band for sheet %s. Check fMin/fMax/fs.',sheetName)
        continue
    end

    [peakAmp,localPeakIdx]=max(P1(bandIdx));
    peakIdx=bandIdx(localPeakIdx);
    fPeak_Hz=f(peakIdx);

    %% half-power bandwidth damping estimate

    halfAmp=peakAmp/sqrt(2);

    leftIdx=bandIdx(bandIdx<peakIdx);
    rightIdx=bandIdx(bandIdx>peakIdx);

    f1=NaN;
    f2=NaN;
    zetaHalfPower=NaN;

    if ~isempty(leftIdx)
        belowLeft=leftIdx(P1(leftIdx)<=halfAmp);
        if ~isempty(belowLeft)
            i1=belowLeft(end);
            i2=i1+1;
            f1=interp1(P1([i1 i2]),f([i1 i2]),halfAmp,'linear','extrap');
        end
    end

    if ~isempty(rightIdx)
        belowRight=rightIdx(P1(rightIdx)<=halfAmp);
        if ~isempty(belowRight)
            i2=belowRight(1);
            i1=i2-1;
            f2=interp1(P1([i1 i2]),f([i1 i2]),halfAmp,'linear','extrap');
        end
    end

    if isfinite(f1) && isfinite(f2) && fPeak_Hz>0
        zetaHalfPower=(f2-f1)/(2*fPeak_Hz);
    end

    %% FFT-guided bandpass and envelope decay estimate

    fLow=max(fMin,fPeak_Hz*(1-bandFrac));
    fHigh=min(fMax,fPeak_Hz*(1+bandFrac));

    yBP=bandpass(yWin,[fLow fHigh],fs);

    env=abs(hilbert(yBP));
    env=movmean(env,max(3,round(0.001*fs)));

    minProm=minPeakFrac*max(env);
    minDist=max(1,round(0.5*fs/fPeak_Hz));

    [envPks,envLocIdx]=findpeaks(env, ...
        'MinPeakProminence',minProm, ...
        'MinPeakDistance',minDist);

    tEnv=tWin(envLocIdx);

    zetaEnvelope=NaN;
    alpha=NaN;

    if length(envPks)>=3
        p=polyfit(tEnv,log(envPks),1);
        alpha=-p(1);
        omegaD=2*pi*fPeak_Hz;
        zetaEnvelope=alpha/sqrt(omegaD^2+alpha^2);
    end

    %% display strings for plot titles

    if isnan(zetaHalfPower)
        hpText='not reliable';
    else
        hpText=sprintf('%.4f',zetaHalfPower);
    end
%% plots

fig=figure;
tiledlayout(2,1,'TileSpacing','compact','Padding','compact')

nexttile
plot(t,y,'LineWidth',1)
hold on
grid on
xlabel('time (s)')
ylabel(axisName,'Interpreter','none')
title(sprintf('%s Impact Signal vs Time',sheetName),'Interpreter','none')

nexttile
plot(f,P1,'LineWidth',1)
hold on
xline(fPeak_Hz,'k--',sprintf('peak = %.1f Hz',fPeak_Hz))
yline(halfAmp,'r--','half-power level')
if isfinite(f1)
    xline(f1,'r--','f_1')
end
if isfinite(f2)
    xline(f2,'r--','f_2')
end
grid on
xlabel('frequency (Hz)')
ylabel('|FFT|')
title(sprintf('Frequency content for Damping: half-power \\zeta = %s',hpText))
xlim([0 fMax])

sgtitle(sprintf('%s damping check from %s',sheetName,axisName), ...
    'FontName','Times New Roman','Interpreter','none')

figName=sprintf('%s_%s_damping_check.png',sheetName,axisName);
exportgraphics(fig,fullfile(outDir,figName),'Resolution',300)
    
    %% collect results

    newRow=table(string(sheetName),string(axisName),fs,tStart,tEnd,fPeak_Hz,f1,f2, ...
        zetaHalfPower,alpha,zetaEnvelope, ...
        'VariableNames',{'sheet','axis','fs_Hz','window_start_s','window_end_s','dominant_freq_Hz','f1_Hz','f2_Hz', ...
        'zeta_half_power','alpha_1_s','zeta_envelope'});

    results=[results;newRow];

end

%% export results

disp(results)
writetable(results,fullfile(outDir,'damping_check_results.xlsx'))