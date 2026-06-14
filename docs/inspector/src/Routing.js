"use strict";

export const _pathname = () => window.location.pathname;

export const _pushPath = (path) => () => {
  if (window.location.pathname !== path) {
    window.history.pushState({}, "", path);
  }
};
