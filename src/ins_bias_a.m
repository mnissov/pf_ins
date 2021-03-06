close all; clear; clc
%% PF INS implementation
addpath(genpath('../toolbox'))
rng(42);

%% generate data
% artificial
Ts = [0.01; 1];
Tf = 200;
turn_rate = 2.5;

add_noise = 3;
add_bias = 3;
gen_data_complex

meas_noise = R_gnss;
sampling_ratio = gnss.Ts/imu.Ts;

%% initialize PF
x0 = [
    zeros(3,1); % pos
    zeros(3,1); % vel
    reshape(Rz(0),9,1); % R
    0*ones(3,1); % b_a
];
P0 = diag([
    1*ones(3,1); % pos
    1e-3*ones(3,1); % vel
    1e-3*ones(9,1); % R
    1e-3*ones(3,1); % b_a
]);
[nx,~] = size(x0);
process_noise = diag([
    1e-2*ones(3,1);         % pos
    10*R_acc(1)*ones(3,1);     % vel
    10*R_gyro(1)*ones(9,1);    % R
    1e-1*ones(3,1);         % b_a
]);
% process_noise = diag([
%     1e-2*ones(3,1);         % pos
%     R_acc(1)*ones(3,1);     % vel
%     R_gyro(1)*ones(9,1);    % R
%     0.0316*ones(3,1);
% %     1e-5*ones(3,1);
% ]);

pf = pf_init(@(x,u) state_fcn(x,u,imu.Ts,process_noise),...
    @meas_likelihood,...
    1e3, x0, P0, 'uniform',...
    10*meas_noise);
pf.ratio = 2/3;
% pf = particleFilter(@(x,u) state_fcn(x,u,imu.Ts),...
%     @(p,z) meas_likelihood(p,z,meas_noise));
% initialize(pf, 1e3, x0, P0);

%% simulate
xV = zeros(numel(gnss.t), nx);
xV(1,:) = x0;
pV = zeros(numel(gnss.t), nx);
pV(1,:) = diag(P0);

ortho_count = 0;
for k=1:numel(gnss.t)
%     if k>=84
%         disp('');
%     end
    pf = pf_correct(pf, gnss.meas(k,:));
    [xV(k,:), pV(k,:)] = pf_estimate(pf);
%     correct(pf, gnss.meas(k,:)');
%     xV(k,:) = pf.State;
%     pV(k,:) = diag(pf.StateCovariance);
    
%     figure(2)
%     scatter3(pf.particles(2,:), pf.particles(1,:), pf.weights,...
%         10,'filled')
%     title(strcat("iteration number ",num2str(k)))
    R = reshape(xV(k,7:15), 3, 3);
    if norm(eye(3)-R'*R,'fro')>=1e-3
        ortho_count = ortho_count+1;
    end
    
    for l=1:sampling_ratio
        pf = pf_predict(pf, imu.meas(sampling_ratio*(k-1)+l,:));
%         predict(pf, imu.meas(sampling_ratio*(k-1)+l,:)');
    end
end

figure(2)
scatter3(pf.particles(2,:), pf.particles(1,:), pf.weights,...
    10,'filled')
title(strcat("iteration number ",num2str(k)))
opts = {'interpreter','latex','fontsize',14};
xlabel('$p_e$ $[m]$',...
    opts{:})
ylabel('$p_n$ $[m]$',...
    opts{:})
zlabel('$w$',...
    opts{:})

%% plotting
figure(1)
clf
hold on
plot(gnss.meas(:,2), gnss.meas(:,1),...
        'ro')
plot(xV(:,2), xV(:,1),...
        'kx','markersize',8)
plot(gnss.pos(:,2), gnss.pos(:,1),...
    '--','linewidth',2)
grid on
xlabel('east $[m]$',...
    opts{:})
ylabel('north $[m]$',...
    opts{:})
legend({'$\tilde{p}^t$','$\hat{p}^t$','$p^t$'},...
    opts{:})

figure(4)
clf
subplot(211)
hold on
plot(gnss.t, abs(gnss.pos(:,1)-gnss.meas(:,1)))
plot(gnss.t, abs(gnss.pos(:,1)-xV(:,1)))
grid on
subplot(212)
hold on
plot(gnss.t, abs(gnss.pos(:,2)-gnss.meas(:,2)))
plot(gnss.t, abs(gnss.pos(:,2)-xV(:,2)))
grid on

figure(5)
clf
subplot(321)
hold on
plot(imu.t, imu.b_a(:,1),...
    'linewidth',2)
plot(gnss.t, xV(:,16),...
    '--','linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Acc Bias $[x]$',...
    opts{:})
legend({'$b$','$\hat{b}$'},...
    opts{:})
subplot(323)
hold on
plot(imu.t, imu.b_a(:,2),...
    'linewidth',2)
plot(gnss.t, xV(:,17),...
    '--','linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Acc Bias $[y]$',...
    opts{:})
legend({'$b$','$\hat{b}$'},...
    opts{:})
subplot(325)
hold on
plot(imu.t, imu.b_a(:,3),...
    'linewidth',2)
plot(gnss.t, xV(:,18),...
    '--','linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Acc Bias $[z]$',...
    opts{:})
legend({'$b$','$\hat{b}$'},...
    opts{:})
subplot(322)
hold on
plot(imu.t, imu.b_g(:,1),...
    'linewidth',2)
plot(gnss.t, xV(:,19),...
    '--','linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Gyro Bias $[x]$',...
    opts{:})
legend({'$b$','$\hat{b}$'},...
    opts{:})
subplot(324)
hold on
plot(imu.t, imu.b_g(:,2),...
    'linewidth',2)
plot(gnss.t, xV(:,20),...
    '--','linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Gyro Bias $[y]$',...
    opts{:})
legend({'$b$','$\hat{b}$'},...
    opts{:})
subplot(326)
hold on
plot(imu.t, imu.b_g(:,3),...
    'linewidth',2)
plot(gnss.t, xV(:,21),...
    '--','linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Gyro Bias $[z]$',...
    opts{:})
legend({'$b$','$\hat{b}$'},...
    opts{:})

[sqrt(mean((gnss.pos(:,1)-xV(:,1)).^2)), sqrt(mean((gnss.pos(:,2)-xV(:,2)).^2))]

figure(6)
clf
subplot(211)
hold on
plot(imu.t, imu.vel(:,1))
plot(gnss.t, xV(:,4),...
    'x')
grid on
subplot(212)
hold on
plot(imu.t, imu.vel(:,2))
plot(gnss.t, xV(:,5),...
    'x')
grid on

function [ xk1 ] = state_fcn( x,u,Ts,process_noise )
    dither = chol(process_noise,'lower')*randn(size(x));
    xk1 = x + Ts*(full_state_bias_a(0,x,u)+dither);
end
function [ y ] = meas_fcn( x )
    y = x(1:3,:);
end
function [ likelihood ] = meas_likelihood( particles,meas,meas_noise )
    [nz,~] = size(meas);
    pred_meas = meas_fcn(particles);
    
    residual = pred_meas-meas;
    meas_error_prod = dot(residual, meas_noise\residual, 1);
    
    likelihood = 1/sqrt((2*pi).^nz*det(meas_noise))*exp(-0.5*meas_error_prod);
end