//
//  PSFListModel.qml
//  qml/hifi/commerce/common
//
//  PSFListModel
// "PSF" stands for:
//     - Paged
//     - Sortable
//     - Filterable
//
//  Created by Zach Fox on 2018-05-15
//  Copyright 2018 High Fidelity, Inc.
//
//  Distributed under the Apache License, Version 2.0.
//  See the accompanying file LICENSE or http://www.apache.org/licenses/LICENSE-2.0.html
//

import QtQuick 2.7

Item {

    // Used when printing debug statements
    property string listModelName: endpoint;
    
    // Parameters. Even if you override getPage, below, please set these for clarity and consistency, when applicable.
    // E.g., your getPage function could refer to this sortKey, etc.
    property string endpoint;
    property string sortKey;
    property string searchFilter;
    property string tagsFilter;
    onEndpointChanged: getFirstPage();
    onSortKeyChanged: getFirstPage();
    onSearchFilterChanged: getFirstPage();
    onTagsFilterChanged: getFirstPage();
    property int itemsPerPage: 100;

    // State.
    property int currentPageToRetrieve: 0;  // 0 = before first page. -1 = we have them all. Otherwise 1-based page number.
    property bool retrievedAtLeastOnePage: false;
    // Resets both internal `ListModel`s and resets the page to retrieve to "1".
    function resetModel() {
        tempModel.clear();
        finalModel.clear();
        currentPageToRetrieve = 1;
        retrievedAtLeastOnePage = false
    }

    // Processing one page.

    // Override to return one property of data, and/or to transform the elements. Must return an array of model elements.
    property var processPage: function (data) { return data; }

    // Check consistency and call processPage.
    function handlePage(error, response) {
        console.log("HRS FIXME got", endpoint, error, JSON.stringify(response));
        function fail(message) {
            console.warn("Warning", listModelName, JSON.stringify(message));
            current_page_to_retrieve = -1;
            requestPending = false;
        }
        if (error || (response.status !== 'success')) {
            return fail(error || response.status);
        }
        if (!requestPending) {
            return fail("No request in flight.");
        }
        requestPending = false;
        if (response.current_page && response.current_page !== currentPageToRetrieve) { // Not all endpoints specify this property.
            return fail("Mismatched page, expected:" + currentPageToRetrieve);
        }
        finalModel.append(processPage(response.data || response)); // FIXME keep index steady, and apply any post sort/filter
        retrievedAtLeastOnePage = true;
    }

    // Override either http or getPage.
    property var http: null; // An Item that has a request function.
    property var getPage: function () {  // Any override MUST call handlePage(), above, even if results empty.
        if (!http) { return console.warn("Neither http nor getPage was set in", listModelName); }
        var url = /^\//.test(endpoint) ? (Account.metaverseServerURL + endpoint) : endpoint;
        // FIXME: handle sort and search parameters, and per_page and page parameters
        console.log("HRS FIXME requesting", url);
        http.request({uri: url}, handlePage);
    }

    // Start the show by retrieving data according to `getPage()`.
    // It can be custom-defined by this item's Parent.
    property var getFirstPage: function () {
        resetModel();
        requestPending = true;
        getPage();
    }
    
    property bool requestPending: false; // For de-bouncing getNextPage.
    // This function, will get the _next_ page of data according to `getPage()`.
    // It can be custom-defined by this item's Parent. Typical usage:
    // ListView {
    //    id: theList
    //    model: thisPSFListModelId
    //    onAtYEndChanged: if (theList.atYEnd) { thisPSFListModelId.getNextPage(); }
    //    ...}
    property var getNextPage: function () {
        if (requestPending || currentPageToRetrieve < 0) {
            return;
        }
        console.log("HRS FIXME Fetching Page " + currentPageToRetrieve + " of " + listModelName + "...");
        currentPageToRetrieve++;
        requestPending = true;
        getPage();
    }

    // Redefining members and methods so that the parent of this Item
    // can use PSFListModel as they would a regular ListModel
    property alias model: finalModel;
    property alias count: finalModel.count;
    function clear() { finalModel.clear(); }
    function get(index) { return finalModel.get(index); }
    function remove(index) { return finalModel.remove(index); }
    function setProperty(index, prop, value) { return finalModel.setProperty(index, prop, value); }
    function move(from, to, n) { return finalModel.move(from, to, n); }
    function insert(index, newElement) { finalModel.insert(index, newElement); }
    function append(newElements) { finalModel.append(newElements); }

    // Used while processing page data and sorting
    ListModel {
        id: tempModel;
    }

    // This is the model that the parent of this Item will actually see
    ListModel {
        id: finalModel;
    }


    // Used when sorting model data on the CLIENT
    // Right now, there is no sorting done on the client for
    // any users of PSFListModel, but that could very easily change.
    property string sortColumnName: "";
    property bool isSortingDescending: true;
    property bool valuesAreNumerical: false;

    function swap(a, b) {
        if (a < b) {
            move(a, b, 1);
            move(b - 1, a, 1);
        } else if (a > b) {
            move(b, a, 1);
            move(a - 1, b, 1);
        }
    }

    function partition(begin, end, pivot) {
        if (valuesAreNumerical) {
            var piv = get(pivot)[sortColumnName];
            swap(pivot, end - 1);
            var store = begin;
            var i;

            for (i = begin; i < end - 1; ++i) {
                var currentElement = get(i)[sortColumnName];
                if (isSortingDescending) {
                    if (currentElement > piv) {
                        swap(store, i);
                        ++store;
                    }
                } else {
                    if (currentElement < piv) {
                        swap(store, i);
                        ++store;
                    }
                }
            }
            swap(end - 1, store);

            return store;
        } else {
            var piv = get(pivot)[sortColumnName].toLowerCase();
            swap(pivot, end - 1);
            var store = begin;
            var i;

            for (i = begin; i < end - 1; ++i) {
                var currentElement = get(i)[sortColumnName].toLowerCase();
                if (isSortingDescending) {
                    if (currentElement > piv) {
                        swap(store, i);
                        ++store;
                    }
                } else {
                    if (currentElement < piv) {
                        swap(store, i);
                        ++store;
                    }
                }
            }
            swap(end - 1, store);

            return store;
        }
    }

    function qsort(begin, end) {
        if (end - 1 > begin) {
            var pivot = begin + Math.floor(Math.random() * (end - begin));

            pivot = partition(begin, end, pivot);

            qsort(begin, pivot);
            qsort(pivot + 1, end);
        }
    }

    function quickSort() {
        qsort(0, count)
    }
}