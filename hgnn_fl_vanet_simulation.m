%% GNN-FL Simulation in CR-VANET in 5G Video Generation (Enhanced)
% This script generates an enhanced video simulating GNN-FL in a CR-VANET within a 5G environment.

%% 1. Initialization and Setup
clear; close all; clc;

% Video settings
videoFileName = 'HGNN_FL_CR_VANET_5G_Simulation';
videoFrameRate = 10; % frames per second
videoDuration = 120; % seconds (2 minutes)
numFrames = videoDuration * videoFrameRate;

% Create video writer object
v = VideoWriter(videoFileName);
v.FrameRate = videoFrameRate;
open(v);

% Simulation parameters
areaSize = 1000; % meters x meters
numVehicles = 50;
numRSUs = 5;
numBS = 1; % 5G Base Station

% Vehicle properties
vehicleX = areaSize * rand(1, numVehicles);
vehicleY = areaSize * rand(1, numVehicles);
vehicleSpeed = 10 + 10 * rand(1, numVehicles); % m/s (10-20 m/s)
vehicleDirection = 2 * pi * rand(1, numVehicles); % radians
vehicleCommunicationRange = 150; % meters
vehicleChannel = zeros(1, numVehicles); % Current channel for each vehicle
vehicleColor = zeros(numVehicles, 3); % For visualizing channel usage

% RSU properties (fixed positions)
rsuX = areaSize * rand(1, numRSUs);
rsuY = areaSize * rand(1, numRSUs);
rsuCommunicationRange = 300; % meters

% 5G Base Station properties (fixed position, central)
bsX = areaSize / 2;
bsY = areaSize / 2;
bsCommunicationRange = areaSize; % Covers the entire area

% Spectrum parameters
numChannels = 10;
channelFrequencies = 1:numChannels; % MHz (simplified)
primaryUserChannels = [3, 7]; % Channels occupied by primary users
primaryUserActive = false(1, numChannels); % State of primary users
primaryUserActive(primaryUserChannels) = true; % PUs are active on these channels

% GNN-FL parameters
gnnModelAccuracy = 0.5 * ones(1, numVehicles); % Initial random accuracy
flRoundDuration = 10; % seconds per FL round
flRoundCounter = 0;

% Figure setup
fig = figure('Position', [100, 100, 1000, 800]); % Larger figure
ax = axes('Parent', fig, 'XLim', [0, areaSize], 'YLim', [0, areaSize]);
xlabel('X-coordinate (m)');
ylabel('Y-coordinate (m)');
title('HGNN-FL in CR-VANET in 5G');
grid on;
hold on;

% Plot initial positions
hVehicles = scatter(vehicleX, vehicleY, 50, 'b', 'filled', 'DisplayName', 'Vehicles');
hRSUs = scatter(rsuX, rsuY, 100, 's', 'filled', 'r', 'DisplayName', 'RSUs');
hBS = scatter(bsX, bsY, 150, '^', 'filled', 'g', 'DisplayName', '5G BS');

% Primary User visualization (simplified: just a marker on the channel)
hPUs = gobjects(0);
for i = 1:length(primaryUserChannels)
    % Place a marker for PU activity, e.g., near the BS or a random spot
    pu_x = areaSize * rand();
    pu_y = areaSize * rand();
    hPUs(i) = plot(pu_x, pu_y, 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [0.8 0.2 0.2], 'DisplayName', sprintf('PU on Ch %d', primaryUserChannels(i)));
end

% Communication links (initially empty)
hLinks = gobjects(0);

% Text for dynamic information
hText = text(0.02, 0.98, '', 'Units', 'normalized', 'FontSize', 10, 'Color', 'k', 'VerticalAlignment', 'top');

legend('show', 'Location', 'northwest');

%% 2. Simulation Loop for Video Generation
for frameIdx = 1:numFrames
    currentTime = (frameIdx - 1) / videoFrameRate;

    %% Update Vehicle Positions (More realistic mobility)
    % Randomly change direction every few seconds
    if mod(frameIdx, videoFrameRate * 5) == 0 % Change direction every 5 seconds
        vehicleDirection = 2 * pi * rand(1, numVehicles); % New random direction
    end

    vehicleX = vehicleX + vehicleSpeed .* cos(vehicleDirection) / videoFrameRate;
    vehicleY = vehicleY + vehicleSpeed .* sin(vehicleDirection) / videoFrameRate;

    % Boundary conditions (wrap around)
    vehicleX(vehicleX < 0) = vehicleX(vehicleX < 0) + areaSize;
    vehicleX(vehicleX > areaSize) = vehicleX(vehicleX > areaSize) - areaSize;
    vehicleY(vehicleY < 0) = vehicleY(vehicleY < 0) + areaSize;
    vehicleY(vehicleY > areaSize) = vehicleY(vehicleY > areaSize) - areaSize;

    % Update plot data
    set(hVehicles, 'XData', vehicleX, 'YData', vehicleY);

    %% Clear old links
    if ~isempty(hLinks)
        delete(hLinks);
        hLinks = gobjects(0);
    end

    %% Simulate Communication Links and CR-VANET Aspects
    % Dynamic spectrum sensing and channel assignment
    activeChannels = setdiff(channelFrequencies, primaryUserChannels(primaryUserActive(primaryUserChannels))); % Available channels
    
    % Assign channels to vehicles (simplified: randomly pick from active channels)
    for i = 1:numVehicles
        if ~isempty(activeChannels)
            vehicleChannel(i) = activeChannels(randi(length(activeChannels)));
        else
            vehicleChannel(i) = 0; % No active channel available
        end
        % Color vehicles based on their assigned channel
        if vehicleChannel(i) > 0
            vehicleColor(i, :) = hsv2rgb([vehicleChannel(i)/numChannels, 1, 0.8]);
        else
            vehicleColor(i, :) = [0.5 0.5 0.5]; % Grey if no channel
        end
    end
    set(hVehicles, 'CData', vehicleColor);

    currentLinks = 0;

    % Vehicle-to-Vehicle (V2V) and Vehicle-to-RSU (V2R) communication
    for i = 1:numVehicles
        % V2V
        for j = i+1:numVehicles
            dist = sqrt((vehicleX(i) - vehicleX(j))^2 + (vehicleY(i) - vehicleY(j))^2);
            if dist < vehicleCommunicationRange && vehicleChannel(i) == vehicleChannel(j) && vehicleChannel(i) ~= 0
                currentLinks = currentLinks + 1;
                hLinks(currentLinks) = plot([vehicleX(i), vehicleX(j)], [vehicleY(i), vehicleY(j)], 'k:', 'LineWidth', 0.5, 'Color', vehicleColor(i,:));
            end
        end

        % V2R
        for k = 1:numRSUs
            dist = sqrt((vehicleX(i) - rsuX(k))^2 + (vehicleY(i) - rsuY(k))^2);
            if dist < rsuCommunicationRange && vehicleChannel(i) ~= 0
                currentLinks = currentLinks + 1;
                hLinks(currentLinks) = plot([vehicleX(i), rsuX(k)], [vehicleY(i), rsuY(k)], 'm-', 'LineWidth', 1, 'Color', vehicleColor(i,:));
            end
        end
    end

    % RSU-to-BS (R2B) communication
    for k = 1:numRSUs
        dist = sqrt((rsuX(k) - bsX)^2 + (rsuY(k) - bsY)^2);
        if dist < bsCommunicationRange
            currentLinks = currentLinks + 1;
            hLinks(currentLinks) = plot([rsuX(k), bsX], [rsuY(k), bsY], 'g--', 'LineWidth', 1.5);
        end
    end

    %% Simulate GNN-FL Rounds (simplified)
    if mod(currentTime, flRoundDuration) == 0 && currentTime > 0
        flRoundCounter = flRoundCounter + 1;
        % Simulate aggregation and model update
        avgAccuracy = mean(gnnModelAccuracy);
        gnnModelAccuracy = avgAccuracy + 0.1 * rand(1, numVehicles); % Simulate slight improvement
        gnnModelAccuracy(gnnModelAccuracy > 0.95) = 0.95; % Cap accuracy
        
        % Visual feedback for FL round
        disp(sprintf('FL Round %d completed. Avg GNN Accuracy: %.2f', flRoundCounter, avgAccuracy));
    end

    %% Update Text Information
    infoText = sprintf('Time: %.1f s\nFL Round: %d\nAvg GNN Accuracy: %.2f\nActive Channels: %s', ...
                       currentTime, flRoundCounter, mean(gnnModelAccuracy), mat2str(activeChannels));
    set(hText, 'String', infoText);

    %% Capture frame
    frame = getframe(fig);
    writeVideo(v, frame);

    drawnow limitrate;
end

%% Finalization
close(v);
close(fig);
disp(['Video saved to: ', videoFileName]);

%% Helper Functions (to be added later if needed for more complexity)
% function [newX, newY] = updateVehiclePosition(x, y, speed, direction, dt, areaSize)
%     newX = x + speed * cos(direction) * dt;
%     newY = y + speed * sin(direction) * dt;
%     newX(newX < 0) = newX(newX < 0) + areaSize;
%     newX(newX > areaSize) = newX(newX > areaSize) - areaSize;
%     newY(newY < 0) = newY(newY < 0) + areaSize;
%     newY(newY > areaSize) = newY(newY > areaSize) - areaSize;
% end
