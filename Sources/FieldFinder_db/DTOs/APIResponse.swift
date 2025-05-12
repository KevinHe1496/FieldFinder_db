//
//  APIResponse.swift
//  FieldFinder_db
//
//  Created by Kevin Heredia on 11/5/25.
//
import Vapor
import Fluent

struct APIResponse: Content {
    let success: Bool
    let message: String
}
