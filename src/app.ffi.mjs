import { Ok, Error } from "./gleam.mjs";

export function get_localstorage(key) {
  const json = window.localStorage.getItem(key);
  if (json === null) return new Error(undefined);
  return new Ok(json);
}

export function set_localstorage(key, json) {
  window.localStorage.setItem(key, json);
}

export async function share_results(shareData) {
  if (navigator.canShare && navigator.canShare(shareData)) {
    navigator.share(shareData).catch(console.error);
  } else {
    await navigator.clipboard.writeText(`${shareData.text}`);
    alert("Data copied to clipboard");
  }
}
